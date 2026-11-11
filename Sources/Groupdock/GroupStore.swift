//
//  GroupStore.swift
//  Groupdock
//

import AppKit
import Combine
import Foundation

/// The editor's state. Every edit is saved on its own: the apps of a group
/// reach its stack at once (the Dock watches the folder), and what only the
/// Dock reads at launch (name, presentation, tile, order) waits for one
/// explicit “Appliquer” so the Dock never reloads behind the user's back.
@MainActor
final class GroupStore: ObservableObject {
    @Published private(set) var document = GroupDocument()
    @Published var selection: UUID?
    @Published private(set) var inDock: Set<UUID> = []
    /// Groups whose Dock-level settings changed since the Dock last read them.
    @Published private(set) var pendingDock: Set<UUID> = []
    @Published var error: String?
    @Published private(set) var loaded = false

    let service: DockStackService
    private let queue = DispatchQueue(label: "groupdock.files", qos: .userInitiated)
    /// The group as the Dock last read it, to tell a rename apart.
    private var dockSnapshots: [UUID: DockGroup] = [:]
    private var writeGenerations: [UUID: Int] = [:]

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
                self.document = document
                self.inDock = docked
                for group in document.groups where docked.contains(group.id) { self.dockSnapshots[group.id] = group }
                if self.selection == nil { self.selection = document.groups.first?.id }
                self.loaded = true
            }
        }
    }

    /// Re-reads which stacks are in the Dock: the user may have dragged one out.
    func refreshDockState() {
        let service = service, groups = groups
        queue.async {
            let docked = service.groupsInDock(groups)
            DispatchQueue.main.async { self.inDock = docked }
        }
    }

    // MARK: Editing

    func addGroup() {
        var name = "Nouveau groupe", index = 2
        while groups.contains(where: { $0.name == name }) { name = "Nouveau groupe \(index)"; index += 1 }
        let group = DockGroup(name: name)
        document.groups.append(group)
        selection = group.id
        persist()
    }

    func update(_ group: DockGroup) {
        guard let index = document.groups.firstIndex(where: { $0.id == group.id }),
              document.groups[index] != group else { return }
        let old = document.groups[index]
        document.groups[index] = group
        persist()
        // A docked stack keeps its old folder until the Dock is told the new one.
        if old.folderName != group.folderName, !inDock.contains(group.id) {
            let service = service
            queue.async { service.moveFolder(from: old, to: group) }
        }
        scheduleFolderWrite(group)
        if inDock.contains(group.id), let snapshot = dockSnapshots[group.id] {
            let dockChanged = snapshot.folderName != group.folderName || snapshot.presentation != group.presentation
                || snapshot.tileStyle != group.tileStyle || snapshot.order != group.order
            if dockChanged { pendingDock.insert(group.id) } else { pendingDock.remove(group.id) }
        }
    }

    func moveGroups(from source: IndexSet, to destination: Int) {
        document.groups.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func delete(_ group: DockGroup) {
        let wasInDock = inDock.contains(group.id)
        let docked = dockSnapshots[group.id] ?? group
        document.groups.removeAll { $0.id == group.id }
        inDock.remove(group.id); pendingDock.remove(group.id); dockSnapshots[group.id] = nil
        if selection == group.id { selection = groups.first?.id }
        persist()
        let service = service
        queue.async {
            if wasInDock { service.removeFromDock(docked); service.restartDock() }
            service.removeFolder(for: group)
            service.removeFolder(for: docked)
        }
    }

    // MARK: Dock

    /// Writes the folder, then adds or updates the stack and reloads the Dock.
    func applyToDock(_ group: DockGroup) {
        guard !group.apps.isEmpty else { error = DockStackError.noApps.localizedDescription; return }
        let service = service, previous = dockSnapshots[group.id]
        queue.async {
            do {
                try service.writeFolder(for: group)
                try service.putInDock(group, previous: previous)
                service.restartDock()
                if let previous, previous.folderName != group.folderName { service.removeFolder(for: previous) }
                DispatchQueue.main.async {
                    self.inDock.insert(group.id)
                    self.pendingDock.remove(group.id)
                    self.dockSnapshots[group.id] = group
                }
            } catch {
                DispatchQueue.main.async { self.error = error.localizedDescription }
            }
        }
    }

    func removeFromDock(_ group: DockGroup) {
        let service = service, docked = dockSnapshots[group.id] ?? group
        inDock.remove(group.id); pendingDock.remove(group.id); dockSnapshots[group.id] = nil
        queue.async {
            service.removeFromDock(docked)
            service.restartDock()
            if docked.folderName != group.folderName { service.removeFolder(for: docked) }
        }
    }

    func revealInFinder(_ group: DockGroup) {
        let service = service
        queue.async {
            try? service.writeFolder(for: group)
            let folder = service.folder(for: group)
            DispatchQueue.main.async { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
        }
    }

    // MARK: Disk

    private func persist() {
        let service = service, document = document
        queue.async {
            do { try service.save(document) } catch {
                DispatchQueue.main.async { self.error = error.localizedDescription }
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
                let service = self.service
                self.queue.async { try? service.writeFolder(for: current) }
            }
        }
    }
}
