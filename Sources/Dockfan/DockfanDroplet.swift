//
//  DockfanDroplet.swift
//  Dockfan
//

import AppKit
import ApplicationServices
import Combine
import DroppyKit
import SwiftUI

/// The class Droppy's loader instantiates, named in the bundle's
/// `NSPrincipalClass`. Keep it empty: it runs before the host is ready.
@objc(DockfanPrincipal)
public final class DockfanPrincipal: NSObject, DropletPrincipal {
    public override init() { super.init() }

    @MainActor public func makeDroplet() -> AnyObject { DockfanDroplet() }
}

/// Dockfan: several apps behind one Dock tile.
///
/// A group is a folder of Finder aliases that the Dock shows as one of its
/// own stacks, so the fan, its animation and the way it closes are the
/// Dock's, with or without Droppy. The droplet is the editor, and gives each
/// group a shortcut that opens its stack.
@MainActor
public final class DockfanDroplet: NSObject, ObservableObject, Droplet {
    /// Must equal `DroppyDropletID` in the bundle's Info.plist and `id` in
    /// droplet.json. The loader refuses the bundle if the three disagree.
    public nonisolated static let id: DropletID = "dockfan"

    private var host: DropletHost?
    private var store: GroupStore?
    private var editor: EditorWindowController?
    private var storeChanges: AnyCancellable?
    private var documentChanges: AnyCancellable?
    /// Shortcut ids registered for groups, with the title they were given.
    private var groupShortcuts: [String: String] = [:]

    public func activate(host: DropletHost) throws {
        self.host = host
        let store = GroupStore(root: host.environment.containerDirectory)
        store.load()
        // The settings pane lists the groups, so it follows the store.
        storeChanges = store.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        self.store = store
        if host.isGranted(.globalShortcuts) {
            host.shortcuts.register(id: "open-editor", title: L("Open Dockfan", "Ouvrir Dockfan"), defaultShortcut: nil) { [weak self] in
                self?.openEditor()
            }
            documentChanges = store.$document.receive(on: DispatchQueue.main).sink { [weak self] document in
                MainActor.assumeIsolated { self?.syncShortcuts(document.groups) }
            }
        }
        host.log.info("Dockfan activated")
    }

    public func deactivate() {
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

    /// Opens a group's stack in the Dock, as a click on it would. Without
    /// the stack in the Dock, or without Accessibility, opens the editor on
    /// the group instead, which says what is missing.
    func openStack(_ id: UUID) {
        guard let store, let group = store.groups.first(where: { $0.id == id }) else { return }
        guard let label = store.dockLabel(for: group) else { edit(id); return }
        switch DockPresser.press(label: label) {
        case .opened: break
        case .notTrusted:
            edit(id)
            store.error = L("To open a stack from its shortcut, allow Droppy in System Settings › Privacy & Security › Accessibility.",
                            "Pour ouvrir une pile avec son raccourci, autorisez Droppy dans Réglages Système › Confidentialité et sécurité › Accessibilité.")
        case .notFound:
            edit(id)
        }
    }

    /// One shortcut per group, named after it, that opens its stack.
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
            host.shortcuts.register(id: id, title: title, defaultShortcut: nil) { [weak self] in self?.openStack(groupID) }
            groupShortcuts[id] = title
        }
    }

    fileprivate func newGroup() {
        store?.addGroup()
        openEditor()
    }
}

// MARK: - URLs

extension DockfanDroplet: DropletURLHandling {
    /// `open?group=<id>`, sent by a tile of the custom-fan version that is
    /// still in the Dock: opens the editor on its group, to apply it as a
    /// stack. Anything else is ignored.
    public func handle(_ request: DropletURLRequest) {
        guard request.path == "open", let raw = request.query["group"], raw.count <= 64,
              let id = UUID(uuidString: raw) else { return }
        edit(id)
    }
}

/// Presses a stack's tile in the Dock through Accessibility, which opens it
/// exactly as a click does.
@MainActor
enum DockPresser {
    enum Result { case opened, notTrusted, notFound }

    static func press(label: String) -> Result {
        guard AXIsProcessTrusted() else { return .notTrusted }
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return .notFound }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        for list in children(of: app) {
            for item in children(of: list) where string(item, kAXTitleAttribute) == label
                && string(item, kAXSubroleAttribute) == "AXFolderDockItem" {
                return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success ? .opened : .notFound
            }
        }
        return .notFound
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
        return (value as? [AXUIElement]) ?? []
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}

// MARK: - Settings pane

extension DockfanDroplet: SettingsPaneProviding {
    public func makeSettingsPane(context: SettingsPaneContext) -> AnyView {
        AnyView(DockfanSettings(droplet: self))
    }

    public var settingsSearchEntries: [SettingsSearchEntry] {
        [SettingsSearchEntry(title: L("Dock groups", "Groupes du Dock"), keywords: ["dock", "pile", "stack", "éventail", "groupe", "apps", "dockfan"])]
    }
}

private struct DockfanSettings: View {
    @ObservedObject var droplet: DockfanDroplet

    var body: some View {
        DropletSettingsPane {
            DropletSettingsCard {
                DropletControlRow(title: L("Group editor", "Éditeur de groupes"), icon: "square.stack.3d.up.fill") {
                    Button(L("Open Dockfan", "Ouvrir Dockfan")) { droplet.openEditor() }.buttonStyle(.borderedProminent)
                }
            }
            DropletSettingsSection {
                VStack(alignment: .leading, spacing: 2) {
                    settingsSectionHeader(LocalizedStringKey(L("Groups", "Groupes")))
                    Text(L("Each group is a Dock stack that opens as macOS’s fan.", "Chaque groupe est une pile du Dock qui s’ouvre en éventail macOS."))
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
                            DropletControlRow(title: group.name, icon: "square.stack.3d.up") {
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
