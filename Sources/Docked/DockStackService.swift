//
//  DockStackService.swift
//  Docked
//
//  Each group is a folder of Finder aliases. The Dock shows that folder as a
//  native stack, so the fan, its animation and its dismissal are macOS's own.
//

import Foundation

enum DockStackError: LocalizedError {
    case noApps, writeFailed(String)
    var errorDescription: String? {
        switch self {
        case .noApps: L("Add at least one app to the group.", "Ajoutez au moins une application au groupe.")
        case .writeFailed(let detail): L("Couldn’t write the group: \(detail)", "Impossible d’écrire le groupe : \(detail)")
        }
    }
}

/// File and Dock work. Everything here is called off the main actor.
struct DockStackService: Sendable {
    let root: URL

    var groupsDirectory: URL { root.appendingPathComponent("Groups", isDirectory: true) }
    var backupsDirectory: URL { root.appendingPathComponent("Dock Backups", isDirectory: true) }
    var storeURL: URL { root.appendingPathComponent("groups.json") }

    func folder(for group: DockGroup) -> URL {
        groupsDirectory.appendingPathComponent(group.folderName, isDirectory: true)
    }

    // MARK: Store

    func load() -> GroupDocument {
        guard let data = try? Data(contentsOf: storeURL),
              let document = try? JSONDecoder().decode(GroupDocument.self, from: data) else { return GroupDocument() }
        return document
    }

    func save(_ document: GroupDocument) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: storeURL, options: .atomic)
    }

    // MARK: Folder

    /// Rewrites the group's folder: one alias per app. In the custom order the
    /// first app gets the newest date, because the Dock sorts by date
    /// modified newest first and puts the first item against the Dock and on
    /// top of the closed pile.
    func writeFolder(for group: DockGroup) throws {
        let fm = FileManager.default
        let folder = folder(for: group)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for item in (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.removeItem(at: item)
        }
        let now = Date()
        var used = Set<String>()
        for (index, app) in group.displayedApps.enumerated() {
            guard let target = app.resolvedURL else { continue }
            var label = group.label(for: app)
            while used.contains(label.lowercased()) { label += " " }
            used.insert(label.lowercased())
            let alias = folder.appendingPathComponent(label)
            do {
                let data = try target.bookmarkData(options: .suitableForBookmarkFile,
                                                   includingResourceValuesForKeys: nil, relativeTo: nil)
                try URL.writeBookmarkData(data, to: alias)
                let date = now.addingTimeInterval(-Double(index))
                try fm.setAttributes([.modificationDate: date, .creationDate: date], ofItemAtPath: alias.path)
            } catch {
                throw DockStackError.writeFailed(error.localizedDescription)
            }
        }
        // Touch the folder so the Dock re-reads it even when only dates moved.
        try? fm.setAttributes([.modificationDate: now], ofItemAtPath: folder.path)
    }

    func removeFolder(for group: DockGroup) {
        try? FileManager.default.removeItem(at: folder(for: group))
    }

    /// Renames the folder in place, keeping its aliases.
    func moveFolder(from old: DockGroup, to new: DockGroup) {
        let from = folder(for: old), to = folder(for: new)
        guard from != to, FileManager.default.fileExists(atPath: from.path) else { return }
        try? FileManager.default.removeItem(at: to)
        try? FileManager.default.moveItem(at: from, to: to)
    }

    // MARK: Dock

    private static var domain: CFString { "com.apple.dock" as CFString }
    private static var othersKey: CFString { "persistent-others" as CFString }

    private func others() -> [[String: Any]] {
        CFPreferencesAppSynchronize(Self.domain)
        return (CFPreferencesCopyAppValue(Self.othersKey, Self.domain) as? [[String: Any]]) ?? []
    }

    private static func url(of tile: [String: Any]) -> String? {
        ((tile["tile-data"] as? [String: Any])?["file-data"] as? [String: Any])?["_CFURLString"] as? String
    }

    private func dockURL(for group: DockGroup) -> String {
        URL(fileURLWithPath: folder(for: group).path, isDirectory: true).absoluteString
    }

    /// The groups whose folder is a stack in the Dock right now.
    func groupsInDock(_ groups: [DockGroup]) -> Set<UUID> {
        let urls = Set(others().compactMap(Self.url(of:)))
        return Set(groups.filter { urls.contains(dockURL(for: $0)) }.map(\.id))
    }

    private func tile(for group: DockGroup) -> [String: Any] {
        [
            "tile-type": "directory-tile",
            "tile-data": [
                "file-data": ["_CFURLString": dockURL(for: group), "_CFURLStringType": 15],
                "file-label": group.folderName,
                "file-type": 2,
                "arrangement": group.order.dockArrangement,
                "displayas": group.tileStyle.rawValue,
                "showas": group.presentation.rawValue,
                "preferreditemsize": -1,
            ] as [String: Any],
        ]
    }

    /// Adds the stack, or updates it in place when it is already there.
    /// `previous` is the group as the Dock knows it, for a rename.
    func putInDock(_ group: DockGroup, previous: DockGroup? = nil) throws {
        backupDock()
        var tiles = others()
        let matches: Set<String> = [dockURL(for: group), previous.map(dockURL(for:))].compactMap { $0 }.reduce(into: []) { $0.insert($1) }
        if let index = tiles.firstIndex(where: { Self.url(of: $0).map(matches.contains) == true }) {
            tiles[index] = tile(for: group)
        } else {
            tiles.append(tile(for: group))
        }
        write(tiles)
    }

    func removeFromDock(_ group: DockGroup) {
        backupDock()
        let url = dockURL(for: group)
        write(others().filter { Self.url(of: $0) != url })
    }

    private func write(_ tiles: [[String: Any]]) {
        CFPreferencesSetAppValue(Self.othersKey, tiles as CFArray, Self.domain)
        CFPreferencesAppSynchronize(Self.domain)
    }

    /// Keeps the ten latest copies of the Dock's preferences before any write.
    private func backupDock() {
        let fm = FileManager.default
        let source = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/com.apple.dock.plist")
        try? fm.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        try? fm.copyItem(at: source, to: backupsDirectory.appendingPathComponent("com.apple.dock \(stamp).plist"))
        let backups = ((try? fm.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in backups.dropFirst(10) { try? fm.removeItem(at: old) }
    }

    /// The Dock reads `persistent-others` only when it starts. It is back in
    /// about a second, with every app and window where it was.
    func restartDock() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        // killall returns at once; a hung one is stopped after 5 seconds.
        let pid = process.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { if process.isRunning { kill(pid, SIGTERM) } }
    }
}
