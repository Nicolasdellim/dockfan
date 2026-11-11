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

/// Docked: several apps in one Dock stack that opens as a fan.
///
/// A group is a folder of Finder aliases that the Dock shows as one of its
/// own stacks, so the fan, its animation and the way it closes are the
/// Dock's. The droplet is the editor: it writes the folders, and adds the
/// stacks to the Dock.
@MainActor
public final class DockedDroplet: NSObject, ObservableObject, Droplet {
    /// Must equal `DroppyDropletID` in the bundle's Info.plist and `id` in
    /// droplet.json. The loader refuses the bundle if the three disagree.
    public nonisolated static let id: DropletID = "docked"

    private var host: DropletHost?
    private var store: GroupStore?
    private var editor: EditorWindowController?
    private var storeChanges: AnyCancellable?

    public func activate(host: DropletHost) throws {
        self.host = host
        let store = GroupStore(root: host.environment.containerDirectory)
        store.load()
        // The settings pane lists the groups, so it follows the store.
        storeChanges = store.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        self.store = store
        if host.isGranted(.globalShortcuts) {
            host.shortcuts.register(id: "open-editor", title: L("Open Docked", "Ouvrir Docked"), defaultShortcut: nil) { [weak self] in
                self?.openEditor()
            }
        }
        host.log.info("Docked activated")
    }

    public func deactivate() {
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
    fileprivate func newGroup() {
        store?.addGroup()
        openEditor()
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
                    Text(L("Each group is a Dock stack that opens as a fan.", "Chaque groupe est une pile du Dock qui s’ouvre en éventail."))
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
