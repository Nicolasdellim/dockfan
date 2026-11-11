//
//  GroupStore.swift
//  Docked
//

import AppKit
import Combine
import Foundation

enum InspectorTab: String, CaseIterable, Identifiable {
    case apps = "Apps", style = "Style"
    var id: String { rawValue }
}

/// A short confirmation shown at the bottom of the editor.
struct Notice: Equatable, Identifiable {
    let id = UUID()
    let symbol: String
    let text: String
}

/// The editor's state. Every edit is saved on its own: the apps of a group
/// reach its stack at once (the Dock watches the folder), and what only the
/// Dock reads when it starts (name, presentation, icon, order) waits for one
/// explicit “Appliquer” so the Dock never reloads behind the user's back.
@MainActor
final class GroupStore: ObservableObject {
    @Published private(set) var document = GroupDocument()
    @Published var selection: UUID?
    @Published var inspectorTab: InspectorTab = .apps
    @Published private(set) var inDock: Set<UUID> = []
    /// Groups whose Dock-level settings changed since the Dock last read them.
    @Published private(set) var pendingDock: Set<UUID> = []
    /// Groups being added or applied right now.
    @Published private(set) var working: Set<UUID> = []
    @Published var notice: Notice?
    @Published var error: String?
    @Published private(set) var loaded = false

    let service: DockStackService
    private let queue = DispatchQueue(label: "docked.files", qos: .userInitiated)
    /// The group as the Dock last read it, to tell a rename apart.
    private var dockSnapshots: [UUID: DockGroup] = [:]
    private var writeGenerations: [UUID: Int] = [:]
    private var noticeGeneration = 0

    init(root: URL) {
        service = DockStackService(root: root)
    }

    var groups: [DockGroup] { document.groups }
    var selectedGroup: DockGroup? { groups.first { $0.id == selection } }

    func load() {
        let service = service
        queue.async {
            let document = service.load()
            let docked = service.groupsInDock(document.groups)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.document = document
                    self.inDock = docked
                    for group in document.groups where docked.contains(group.id) { self.dockSnapshots[group.id] = group }
                    if self.selection == nil { self.selection = document.groups.first?.id }
                    self.loaded = true
                }
            }
        }
    }

    /// Re-reads which stacks are in the Dock: the user may have dragged one out.
    func refreshDockState() {
        let service = service, groups = groups.map { group in dockSnapshots[group.id] ?? group }
        queue.async {
            let docked = service.groupsInDock(groups)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    for id in self.inDock.subtracting(docked) {
                        self.dockSnapshots[id] = nil
                        self.pendingDock.remove(id)
                    }
                    self.inDock = docked
                }
            }
        }
    }

    // MARK: Editing

    @discardableResult
    func addGroup(named base: String = L("New group", "Nouveau groupe"), apps: [AppEntry] = []) -> DockGroup {
        var name = base, index = 2
        while groups.contains(where: { $0.folderName.lowercased() == DockGroup(name: name).folderName.lowercased() }) {
            name = "\(base) \(index)"; index += 1
        }
        let group = DockGroup(name: name, apps: apps)
        document.groups.append(group)
        selection = group.id
        inspectorTab = .apps
        persist()
        if !apps.isEmpty { scheduleFolderWrite(group) }
        return group
    }

    func duplicate(_ group: DockGroup) {
        var copy = addGroup(named: group.name + L(" copy", " copie"),
                            apps: group.apps.map { AppEntry(name: $0.name, path: $0.path, bundleIdentifier: $0.bundleIdentifier) })
        copy.presentation = group.presentation
        copy.tileStyle = group.tileStyle
        copy.order = group.order
        copy.showsExtension = group.showsExtension
        update(copy)
        show("plus.square.on.square", "Groupe dupliqué")
    }

    /// Whether another group already uses this name, which would make the
    /// two share one folder.
    func nameIsTaken(_ name: String, by id: UUID) -> Bool {
        let folder = DockGroup(name: name).folderName.lowercased()
        return groups.contains { $0.id != id && $0.folderName.lowercased() == folder }
    }

    func update(_ group: DockGroup) {
        guard let index = document.groups.firstIndex(where: { $0.id == group.id }),
              document.groups[index] != group else { return }
        let old = document.groups[index]
        var group = group
        // Two groups never share a folder: a taken name is not saved.
        if nameIsTaken(group.name, by: group.id) { group.name = old.name }
        document.groups[index] = group
        persist()
        // A docked stack keeps its old folder until the Dock is told the new one.
        if old.folderName != group.folderName, !inDock.contains(group.id) {
            let service = service, renamed = group
            queue.async { service.moveFolder(from: old, to: renamed) }
        }
        scheduleFolderWrite(group)
        if inDock.contains(group.id), let snapshot = dockSnapshots[group.id] {
            if snapshot.differsForDock(from: group) { pendingDock.insert(group.id) } else { pendingDock.remove(group.id) }
        }
    }

    func moveGroups(from source: IndexSet, to destination: Int) {
        document.groups.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func delete(_ group: DockGroup) {
        let wasInDock = inDock.contains(group.id)
        let docked = dockSnapshots[group.id] ?? group
        let index = groups.firstIndex { $0.id == group.id } ?? 0
        document.groups.removeAll { $0.id == group.id }
        inDock.remove(group.id); pendingDock.remove(group.id); dockSnapshots[group.id] = nil
        if selection == group.id { selection = groups.isEmpty ? nil : groups[min(index, groups.count - 1)].id }
        persist()
        let service = service
        queue.async {
            if wasInDock { service.removeFromDock(docked); service.restartDock() }
            service.removeFolder(for: group)
            service.removeFolder(for: docked)
        }
        show("trash", "« \(group.name) » supprimé")
    }

    // MARK: Dock

    /// Writes the folder, then adds or updates the stack and reloads the Dock.
    func applyToDock(_ group: DockGroup) {
        guard !group.apps.isEmpty else { error = DockStackError.noApps.localizedDescription; return }
        guard !working.contains(group.id) else { return }
        let service = service, previous = dockSnapshots[group.id], wasInDock = inDock.contains(group.id)
        working.insert(group.id)
        queue.async {
            do {
                try service.writeFolder(for: group)
                try service.putInDock(group, previous: previous)
                service.restartDock()
                if let previous, previous.folderName != group.folderName { service.removeFolder(for: previous) }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self.working.remove(group.id)
                        self.inDock.insert(group.id)
                        self.pendingDock.remove(group.id)
                        self.dockSnapshots[group.id] = group
                        self.show("checkmark.circle.fill", wasInDock ? L("Dock updated", "Dock mis à jour") : L("“\(group.name)” is in the Dock", "« \(group.name) » est dans le Dock"))
                    }
                }
            } catch {
                let message = error.localizedDescription
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self.working.remove(group.id)
                        self.error = message
                    }
                }
            }
        }
    }

    func removeFromDock(_ group: DockGroup) {
        let service = service, docked = dockSnapshots[group.id] ?? group
        inDock.remove(group.id); pendingDock.remove(group.id); dockSnapshots[group.id] = nil
        queue.async {
            service.removeFromDock(docked)
            service.restartDock()
            if docked.folderName != group.folderName {
                service.removeFolder(for: docked)
                try? service.writeFolder(for: group)
            }
        }
        show("minus.circle", "Retiré du Dock")
    }

    func revealInFinder(_ group: DockGroup) {
        let service = service
        let shown = folderGroup(for: group)
        queue.async {
            try? service.writeFolder(for: shown)
            let folder = service.folder(for: shown)
            DispatchQueue.main.async { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
        }
    }

    /// The group as its folder is named on disk: a docked group waiting for a
    /// rename still lives in the folder the Dock shows.
    private func folderGroup(for group: DockGroup) -> DockGroup {
        var target = group
        if inDock.contains(group.id), let snapshot = dockSnapshots[group.id] { target.name = snapshot.name }
        return target
    }

    // MARK: Notices

    func show(_ symbol: String, _ text: String) {
        noticeGeneration += 1
        let generation = noticeGeneration
        notice = Notice(symbol: symbol, text: text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.noticeGeneration == generation else { return }
                self.notice = nil
            }
        }
    }

    // MARK: Disk

    private func persist() {
        let service = service, document = document
        queue.async {
            do { try service.save(document) } catch {
                let message = error.localizedDescription
                DispatchQueue.main.async { MainActor.assumeIsolated { self.error = message } }
            }
        }
    }

    /// Coalesces a burst of edits (a drag through a list) into one write.
    /// The wait happens on the main actor; only the write goes to `queue`,
    /// through `async`'s @Sendable closure. A `DispatchWorkItem` built here
    /// would inherit the main actor and trap when the queue runs it.
    private func scheduleFolderWrite(_ group: DockGroup) {
        let generation = (writeGenerations[group.id] ?? 0) + 1
        writeGenerations[group.id] = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.writeGenerations[group.id] == generation,
                      let current = self.groups.first(where: { $0.id == group.id }) else { return }
                let target = self.folderGroup(for: current)
                let service = self.service
                self.queue.async { try? service.writeFolder(for: target) }
            }
        }
    }
}

extension DockGroup {
    /// Settings the Dock reads only when it starts.
    func differsForDock(from other: DockGroup) -> Bool {
        folderName != other.folderName || presentation != other.presentation
            || tileStyle != other.tileStyle || order != other.order
    }
}
