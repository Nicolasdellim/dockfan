//
//  GroupStore.swift
//  Dockfan
//

import AppKit
import Combine
import Foundation

enum InspectorTab: String, CaseIterable, Identifiable {
    case apps, opening, icon
    var id: String { rawValue }
    var title: String {
        switch self {
        case .apps: "Apps"
        case .icon: L("Dock icon", "Icône")
        case .opening: L("Fan", "Éventail")
        }
    }
    var symbol: String {
        switch self {
        case .apps: "square.grid.2x2"
        case .icon: "app.badge"
        case .opening: "rectangle.stack"
        }
    }
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
    /// The group whose name is being edited in the sidebar.
    @Published var renaming: UUID?
    @Published private(set) var inDock: Set<UUID> = []
    /// Groups whose Dock-level settings changed since the Dock last read them.
    @Published private(set) var pendingDock: Set<UUID> = []
    /// Groups being added or applied right now.
    @Published private(set) var working: Set<UUID> = []
    @Published var notice: Notice?
    @Published var error: String?
    @Published private(set) var loaded = false
    /// Pictures chosen for icons, by file name, loaded once.
    @Published private(set) var images: [String: NSImage] = [:]
    /// Where a folder tile sends its click: `droppy://droplet/dockfan`. Set by
    /// the droplet; `nil` in a host that can't deliver URLs.
    var callbackBase: URL?

    let service: DockStackService
    private let queue = DispatchQueue(label: "dockfan.files", qos: .userInitiated)
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
            let names = document.groups.compactMap(\.iconImage)
            let pictures = Dictionary(names.compactMap { name in
                (try? Data(contentsOf: service.imageURL(name))).map { (name, $0) }
            }, uniquingKeysWith: { a, _ in a })
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    for (name, data) in pictures { self.images[name] = NSImage(data: data) }
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
        var group = DockGroup(name: name, apps: apps)
        // New groups are drawn by Dockfan, with their apps as the icon.
        if callbackBase != nil { group.mode = .folder; group.tileStyle = .appGrid }
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
        copy.mode = group.mode
        copy.tileStyle = group.tileStyle == .image ? .appGrid : group.tileStyle
        copy.order = group.order
        copy.showsExtension = group.showsExtension
        copy.iconApp = nil
        copy.iconFinish = group.iconFinish
        copy.iconGrid = group.iconGrid
        copy.panel = group.panel
        update(copy)
        show("plus.square.on.square", L("Group duplicated", "Groupe dupliqué"))
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

    /// Renames a group; a name another group has is refused. A docked
    /// group's tile follows on the next “Apply to Dock”.
    @discardableResult
    func rename(_ id: UUID, to name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var group = groups.first(where: { $0.id == id }) else { return false }
        guard !nameIsTaken(trimmed, by: id) else {
            error = L("Another group is already called “\(trimmed)”.", "Un autre groupe s’appelle déjà « \(trimmed) ».")
            return false
        }
        guard group.name != trimmed else { return true }
        group.name = trimmed
        update(group)
        show("pencil", inDock.contains(id) ? L("Renamed. Apply to update the Dock.", "Renommé. Appliquez pour mettre le Dock à jour.")
                                           : L("Renamed “\(trimmed)”", "Renommé « \(trimmed) »"))
        return true
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
            service.removeLauncher(for: group)
            service.removeImage(group.iconImage)
        }
        if let name = group.iconImage { images[name] = nil }
        show("trash", L("“\(group.name)” deleted", "« \(group.name) » supprimé"))
    }

    // MARK: Dock

    /// Writes what the group needs (its folder of aliases, its icon, its
    /// launcher), puts its tile in the Dock and reloads the Dock.
    func applyToDock(_ group: DockGroup) {
        guard !group.apps.isEmpty else { error = DockStackError.noApps.localizedDescription; return }
        guard !working.contains(group.id) else { return }
        if group.mode == .folder, callbackBase == nil {
            error = L("This version of Droppy can’t open folders from the Dock. Update Droppy, or use a stack.",
                      "Cette version de Droppy ne peut pas ouvrir de dossier depuis le Dock. Mettez Droppy à jour, ou utilisez une pile.")
            return
        }
        let service = service, previous = dockSnapshots[group.id], wasInDock = inDock.contains(group.id)
        // Drawing needs the main actor; the files and the Dock don't.
        // A launcher always carries an icon; a stack only a composed one.
        let icon = group.effectiveTileStyle.isComposed || group.mode == .folder
            ? ComposedIcon.pngData(for: group, image: image(for: group)) : nil
        let openURL = callbackBase.flatMap { base -> URL? in
            var components = URLComponents(url: base.appendingPathComponent("open"), resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "group", value: group.id.uuidString)]
            return components?.url
        }
        working.insert(group.id)
        queue.async {
            do {
                switch group.mode {
                case .stack:
                    try service.writeFolder(for: group)
                    service.setFolderIcon(icon, for: group)
                case .folder:
                    guard let openURL else { throw DockStackError.launcherFailed("URL") }
                    try service.writeLauncher(for: group, iconPNG: icon, openURL: openURL)
                }
                try service.putInDock(group, previous: previous)
                service.restartDock()
                if let previous, previous.folderName != group.folderName || group.mode == .folder {
                    service.removeFolder(for: previous)
                }
                if group.mode == .stack { service.removeLauncher(for: group) }
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
            service.removeLauncher(for: group)
            if docked.folderName != group.folderName {
                service.removeFolder(for: docked)
                try? service.writeFolder(for: group)
            }
        }
        show("minus.circle", L("Removed from the Dock", "Retiré du Dock"))
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

    // MARK: Looks

    func image(for group: DockGroup) -> NSImage? { group.iconImage.flatMap { images[$0] } }

    /// Copies a picture into Dockfan's folder and makes it the group's icon.
    func importImage(from url: URL, for id: UUID) {
        let service = service
        let access = url.startAccessingSecurityScopedResource()
        queue.async {
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let name = try service.importImage(from: url)
                let data = try Data(contentsOf: service.imageURL(name))
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard var group = self.groups.first(where: { $0.id == id }) else { return }
                        let old = group.iconImage
                        self.images[name] = NSImage(data: data)
                        group.iconImage = name
                        group.tileStyle = .image
                        self.update(group)
                        // The old picture stays while the Dock may still show it.
                        if let old, old != self.dockSnapshots[id]?.iconImage {
                            self.images[old] = nil
                            self.queue.async { service.removeImage(old) }
                        }
                    }
                }
            } catch {
                let message = error.localizedDescription
                DispatchQueue.main.async { MainActor.assumeIsolated { self.error = message } }
            }
        }
    }

    /// A random look, as TinyFolder's shuffle: a finish, a grid and, for a
    /// folder, a panel tint and layout.
    func shuffleLook(of group: DockGroup) {
        var group = group
        let finishes = Finish.allCases.filter { $0 != group.iconFinish }
        group.iconFinish = finishes.randomElement() ?? .glass
        if group.tileStyle != .image { group.tileStyle = .appGrid }
        group.iconGrid = group.apps.count > 4 && Bool.random() ? 3 : 2
        update(group)
    }

    /// A random fan: a preset, a colour, a curve and a motion.
    func shuffleOpening(of group: DockGroup) {
        var group = group
        LookPreset.all.randomElement()?.apply(&group.panel)
        group.panel.customTint = nil
        group.panel.tint = Finish.allCases.randomElement()
        group.panel.labels = FanLabels.allCases.randomElement() ?? .dark
        group.panel.curve = [0, 0.3, 0.55, 0.9].randomElement() ?? 0.55
        group.panel.opening = OpenAnimation.allCases.randomElement() ?? .spring
        group.panel.hover = [.zoom, .glow].randomElement() ?? .zoom
        update(group)
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
                      let current = self.groups.first(where: { $0.id == group.id }),
                      current.mode == .stack else { return }
                let target = self.folderGroup(for: current)
                let service = self.service
                self.queue.async { try? service.writeFolder(for: target) }
            }
        }
    }
}

extension DockGroup {
    /// Settings the Dock reads only when it starts: its tile, its label, its
    /// icon. The apps of a stack reach it on their own; the panel of a folder
    /// is Dockfan's and changes at once.
    func differsForDock(from other: DockGroup) -> Bool {
        if folderName != other.folderName || mode != other.mode || effectiveTileStyle != other.effectiveTileStyle { return true }
        if mode == .stack, order != other.order { return true }
        switch effectiveTileStyle {
        case .appGrid:
            let n = iconGrid * iconGrid
            return iconFinish != other.iconFinish || iconGrid != other.iconGrid
                || displayedApps.prefix(n).map(\.path) != other.displayedApps.prefix(n).map(\.path)
        case .image:
            return iconImage != other.iconImage
        case .singleApp:
            return singleApp?.path != other.singleApp?.path
        case .stack, .folder:
            return false
        }
    }
}
