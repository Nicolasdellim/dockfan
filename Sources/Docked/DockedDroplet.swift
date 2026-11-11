//
//  DockedDroplet.swift
//  Docked
//

import Combine
import DroppyKit
import SwiftUI

/// The class Droppy's loader instantiates, named in the bundle's
/// `NSPrincipalClass`. Keep it empty: it runs before the host is ready.
@objc(DockedPrincipal)
public final class DockedPrincipal: NSObject, DropletPrincipal {
    public override init() { super.init() }

    @MainActor public func makeDroplet() -> AnyObject { DockedDroplet() }
}

/// Docked: several apps behind one Dock tile.
///
/// A stack is a folder of Finder aliases that the Dock shows as one of its
/// own stacks, so the fan, its animation and the way it closes are the
/// Dock's. A folder is a small launcher among the apps whose click comes
/// back here as `droppy://droplet/docked/open?group=…` and opens Docked's
/// glass panel. The droplet is also the editor.
@MainActor
public final class DockedDroplet: NSObject, ObservableObject, Droplet {
    /// Must equal `DroppyDropletID` in the bundle's Info.plist and `id` in
    /// droplet.json. The loader refuses the bundle if the three disagree.
    public nonisolated static let id: DropletID = "docked"

    private var host: DropletHost?
    private var store: GroupStore?
    private var editor: EditorWindowController?
    private var storeChanges: AnyCancellable?
    private var documentChanges: AnyCancellable?
    private let panel = FolderPanelController()
    /// Shortcut ids registered for groups, with the title they were given.
    private var groupShortcuts: [String: String] = [:]

    public func activate(host: DropletHost) throws {
        self.host = host
        let store = GroupStore(root: host.environment.containerDirectory)
        store.callbackBase = host.environment.dropletCallbackURL
        store.load()
        // The settings pane lists the groups, so it follows the store.
        storeChanges = store.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        self.store = store
        if host.isGranted(.globalShortcuts) {
            host.shortcuts.register(id: "open-editor", title: L("Open Docked", "Ouvrir Docked"), defaultShortcut: nil) { [weak self] in
                self?.openEditor()
            }
            documentChanges = store.$document.receive(on: DispatchQueue.main).sink { [weak self] document in
                MainActor.assumeIsolated { self?.syncShortcuts(document.groups) }
            }
        }
        panel.onEdit = { [weak self] id in self?.edit(id) }
        host.log.info("Docked activated")
    }

    public func deactivate() {
        panel.close()
        documentChanges = nil
        groupShortcuts.removeAll()
        editor?.close()
        editor = nil
        storeChanges = nil
        store = nil
        host = nil
    }

    func openEditor() {
        guard let store else { return }
        if editor == nil { editor = EditorWindowController(store: store) }
        editor?.show()
        store.refreshDockState()
    }

    fileprivate var groups: [DockGroup] { store?.groups ?? [] }
    fileprivate func isInDock(_ group: DockGroup) -> Bool { store?.inDock.contains(group.id) == true }
    fileprivate func edit(_ group: DockGroup) {
        store?.selection = group.id
        openEditor()
    }
    private func edit(_ id: UUID) {
        store?.selection = id
        openEditor()
    }

    /// Opens a group's panel, whatever its mode: from its folder tile, or
    /// from its shortcut.
    func togglePanel(_ id: UUID) {
        guard let group = store?.groups.first(where: { $0.id == id }) else { return }
        panel.toggle(group)
    }

    /// One shortcut per group, named after it, that opens its panel.
    private func syncShortcuts(_ groups: [DockGroup]) {
        guard let host, host.isGranted(.globalShortcuts) else { return }
        var wanted: [String: (UUID, String)] = [:]
        for group in groups {
            wanted["group-\(group.id.uuidString.lowercased())"] = (group.id, L("Open “\(group.name)”", "Ouvrir « \(group.name) »"))
        }
        for id in groupShortcuts.keys where wanted[id] == nil {
            host.shortcuts.unregister(id: id)
            groupShortcuts[id] = nil
        }
        for (id, (groupID, title)) in wanted where groupShortcuts[id] != title {
            host.shortcuts.register(id: id, title: title, defaultShortcut: nil) { [weak self] in self?.togglePanel(groupID) }
            groupShortcuts[id] = title
        }
    }

    fileprivate func newGroup() {
        store?.addGroup()
        openEditor()
    }
}

// MARK: - URLs

extension DockedDroplet: DropletURLHandling {
    /// `open?group=<id>`: a folder tile was clicked. Anything else, or an
    /// unknown group, is ignored: every app on the Mac can open these URLs.
    public func handle(_ request: DropletURLRequest) {
        guard request.path == "open", let raw = request.query["group"], raw.count <= 64,
              let id = UUID(uuidString: raw) else { return }
        togglePanel(id)
    }
}

// MARK: - Settings pane

extension DockedDroplet: SettingsPaneProviding {
    public func makeSettingsPane(context: SettingsPaneContext) -> AnyView {
        AnyView(DockedSettings(droplet: self))
    }

    public var settingsSearchEntries: [SettingsSearchEntry] {
        [SettingsSearchEntry(title: L("Dock groups", "Groupes du Dock"), keywords: ["dock", "pile", "stack", "éventail", "groupe", "apps", "docked"])]
    }
}

private struct DockedSettings: View {
    @ObservedObject var droplet: DockedDroplet

    var body: some View {
        DropletSettingsPane {
            DropletSettingsCard {
                DropletControlRow(title: L("Group editor", "Éditeur de groupes"), icon: "square.stack.3d.up.fill") {
                    Button(L("Open Docked", "Ouvrir Docked")) { droplet.openEditor() }.buttonStyle(.borderedProminent)
                }
            }
            DropletSettingsSection {
                VStack(alignment: .leading, spacing: 2) {
                    settingsSectionHeader(LocalizedStringKey(L("Groups", "Groupes")))
                    Text(L("A stack opens as the Dock’s fan; a folder opens a glass panel.", "Une pile s’ouvre en éventail ; un dossier ouvre un panneau en verre."))
                        .font(.body).foregroundStyle(.secondary)
                }
            } content: {
                DropletSettingsCard {
                    if droplet.groups.isEmpty {
                        DropletControlRow(title: L("No groups yet", "Aucun groupe pour l’instant"), icon: "square.dashed") {
                            Button(L("Create a group", "Créer un groupe")) { droplet.newGroup() }.buttonStyle(.bordered)
                        }
                    } else {
                        ForEach(droplet.groups) { group in
                            DropletControlRow(title: group.name, icon: group.mode == .stack ? "square.stack.3d.up" : "square.grid.2x2") {
                                HStack(spacing: 10) {
                                    DropletValuePill(text: droplet.isInDock(group) ? L("In the Dock", "Dans le Dock")
                                                     : group.apps.count == 1 ? "1 app" : "\(group.apps.count) apps")
                                    Button(L("Edit", "Modifier")) { droplet.edit(group) }.buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
