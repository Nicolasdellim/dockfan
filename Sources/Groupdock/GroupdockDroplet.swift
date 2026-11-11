//
//  GroupdockDroplet.swift
//  Groupdock
//

import Combine
import DroppyKit
import SwiftUI

/// The class Droppy's loader instantiates, named in the bundle's
/// `NSPrincipalClass`. Keep it empty: it runs before the host is ready.
@objc(GroupdockPrincipal)
public final class GroupdockPrincipal: NSObject, DropletPrincipal {
    public override init() { super.init() }

    @MainActor public func makeDroplet() -> AnyObject { GroupdockDroplet() }
}

/// GroupDock: several apps in one Dock stack that opens as a fan.
///
/// A group is a folder of aliases shown by the Dock as a native stack, so the
/// fan, its animation and the way it closes are the Dock's own. The droplet
/// is the editor: it writes the folders and adds the stacks to the Dock.
@MainActor
public final class GroupdockDroplet: NSObject, ObservableObject, Droplet {
    public nonisolated static let id: DropletID = "groupdock"

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
            host.shortcuts.register(id: "open-editor", title: "Ouvrir GroupDock", defaultShortcut: nil) { [weak self] in
                self?.openEditor()
            }
        }
        host.log.info("GroupDock activated")
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
    }

    fileprivate var groups: [DockGroup] { store?.groups ?? [] }
    fileprivate func isInDock(_ group: DockGroup) -> Bool { store?.inDock.contains(group.id) == true }
    fileprivate func open(_ group: DockGroup) {
        store?.selection = group.id
        openEditor()
    }
}

// MARK: - Settings pane

extension GroupdockDroplet: SettingsPaneProviding {
    public func makeSettingsPane(context: SettingsPaneContext) -> AnyView {
        AnyView(GroupdockSettings(droplet: self))
    }

    public var settingsSearchEntries: [SettingsSearchEntry] {
        [SettingsSearchEntry(title: "Groupes du Dock", keywords: ["dock", "pile", "stack", "éventail", "groupe", "apps"])]
    }
}

private struct GroupdockSettings: View {
    @ObservedObject var droplet: GroupdockDroplet

    var body: some View {
        DropletSettingsPane {
            DropletSettingsCard {
                DropletControlRow(title: "Éditeur de groupes", icon: "square.stack.3d.up.fill") {
                    Button("Ouvrir") { droplet.openEditor() }.buttonStyle(.borderedProminent)
                }
            }
            DropletSettingsSection {
                settingsSectionHeader("Groupes")
            } content: {
                DropletSettingsCard {
                    if droplet.groups.isEmpty {
                        DropletControlRow(title: "Aucun groupe pour l’instant", icon: "square.stack.3d.up") {
                            Button("Créer") { droplet.openEditor() }.buttonStyle(.bordered)
                        }
                    } else {
                        ForEach(droplet.groups) { group in
                            DropletControlRow(title: group.name, icon: "square.stack.3d.up") {
                                HStack(spacing: 10) {
                                    DropletValuePill(text: droplet.isInDock(group) ? "Dans le Dock" : "\(group.apps.count) apps")
                                    Button("Modifier") { droplet.open(group) }.buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
