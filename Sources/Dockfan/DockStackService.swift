//
//  DockStackService.swift
//  Dockfan
//
//  A group is a folder of Finder aliases that the Dock shows as one of its
//  own stacks (`persistent-others`): the fan, its animation, the way it
//  closes, “Open in Finder” and its right-click options are all macOS's, and
//  work whether Droppy is open or not.
//

import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum DockStackError: LocalizedError {
    case noApps, writeFailed(String), launcherFailed(String)
    var errorDescription: String? {
        switch self {
        case .noApps: L("Add at least one app to the group.", "Ajoutez au moins une application au groupe.")
        case .writeFailed(let detail): L("Couldn’t write the group: \(detail)", "Impossible d’écrire le groupe : \(detail)")
        case .launcherFailed(let detail): L("Couldn’t make the folder’s Dock tile: \(detail)", "Impossible de créer la tuile du dossier : \(detail)")
        }
    }
}

/// File and Dock work. Everything here is called off the main actor, except
/// where a method says otherwise.
struct DockStackService: Sendable {
    let root: URL

    var groupsDirectory: URL { root.appendingPathComponent("Groups", isDirectory: true) }
    var launchersDirectory: URL { root.appendingPathComponent("Launchers", isDirectory: true) }
    var imagesDirectory: URL { root.appendingPathComponent("Images", isDirectory: true) }
    var backupsDirectory: URL { root.appendingPathComponent("Dock Backups", isDirectory: true) }
    var storeURL: URL { root.appendingPathComponent("groups.json") }

    func folder(for group: DockGroup) -> URL {
        groupsDirectory.appendingPathComponent(group.folderName, isDirectory: true)
    }

    func launcher(for group: DockGroup) -> URL {
        launchersDirectory.appendingPathComponent(group.id.uuidString, isDirectory: true)
            .appendingPathComponent(group.folderName + ".app", isDirectory: true)
    }

    func imageURL(_ name: String) -> URL { imagesDirectory.appendingPathComponent(name) }

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

    // MARK: Images

    /// Copies a picture the user chose into Dockfan's folder, as a square-ish
    /// PNG of at most 1024 pixels. Returns its file name.
    func importImage(from url: URL) throws -> String {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 1024,
                  kCGImageSourceCreateThumbnailWithTransform: true,
              ] as CFDictionary) else {
            throw DockStackError.writeFailed(L("This file is not a picture.", "Ce fichier n’est pas une image."))
        }
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".png"
        guard let destination = CGImageDestinationCreateWithURL(imageURL(name) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw DockStackError.writeFailed(name)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw DockStackError.writeFailed(name) }
        return name
    }

    func removeImage(_ name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: imageURL(name))
    }

    // MARK: Stack folder

    /// The Finder file that holds a folder's custom icon. Never an alias.
    private static let iconFile = "Icon\r"

    /// Rewrites the group's folder: one alias per app. In the custom order the
    /// first app gets the newest date, because the Dock sorts by date
    /// modified newest first and puts the first item against the Dock and on
    /// top of the closed pile.
    func writeFolder(for group: DockGroup) throws {
        let fm = FileManager.default
        let folder = folder(for: group)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for item in (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        where item.lastPathComponent != Self.iconFile {
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

    /// Gives the stack's folder Dockfan's icon, or takes it away (`nil`).
    func setFolderIcon(_ png: Data?, for group: DockGroup) {
        let path = folder(for: group).path
        let image = png.flatMap(NSImage.init(data:))
        DispatchQueue.main.sync { _ = NSWorkspace.shared.setIcon(image, forFile: path, options: []) }
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

    // MARK: Earlier launchers

    /// Groups of an earlier version could be a launcher app among the apps;
    /// this removes what is left of one.
    func removeLauncher(for group: DockGroup) {
        let directory = launchersDirectory.appendingPathComponent(group.id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: Dock

    private static var domain: CFString { "com.apple.dock" as CFString }
    private static var othersKey: CFString { "persistent-others" as CFString }
    private static var appsKey: CFString { "persistent-apps" as CFString }

    private func tiles(_ key: CFString) -> [[String: Any]] {
        CFPreferencesAppSynchronize(Self.domain)
        return (CFPreferencesCopyAppValue(key, Self.domain) as? [[String: Any]]) ?? []
    }

    private func write(_ tiles: [[String: Any]], _ key: CFString) {
        CFPreferencesSetAppValue(key, tiles as CFArray, Self.domain)
        CFPreferencesAppSynchronize(Self.domain)
    }

    private static func url(of tile: [String: Any]) -> String? {
        ((tile["tile-data"] as? [String: Any])?["file-data"] as? [String: Any])?["_CFURLString"] as? String
    }

    private func stackURL(for group: DockGroup) -> String {
        URL(fileURLWithPath: folder(for: group).path, isDirectory: true).absoluteString
    }


    /// Every launcher of a group lives in its own id folder, whatever its name.
    private func isLauncher(_ url: String, of group: DockGroup) -> Bool {
        url.contains("/Launchers/\(group.id.uuidString)/")
    }

    /// The groups that have a tile in the Dock right now, in either form.
    func groupsInDock(_ groups: [DockGroup]) -> Set<UUID> {
        let stacks = Set(tiles(Self.othersKey).compactMap(Self.url(of:)))
        let apps = tiles(Self.appsKey).compactMap(Self.url(of:))
        return Set(groups.filter { group in
            stacks.contains(stackURL(for: group)) || apps.contains { isLauncher($0, of: group) }
        }.map(\.id))
    }

    private func stackTile(for group: DockGroup) -> [String: Any] {
        [
            "tile-type": "directory-tile",
            "tile-data": [
                "file-data": ["_CFURLString": stackURL(for: group), "_CFURLStringType": 15],
                "file-label": group.folderName,
                "file-type": 2,
                "arrangement": group.order.dockArrangement,
                // A composed icon is the folder's own icon, shown as a folder.
                "displayas": group.effectiveTileStyle == .stack ? 0 : 1,
                "showas": StackPresentation.fan.rawValue,
            ] as [String: Any],
        ]
    }

    /// Adds the group's tile, or updates it in place. `previous` is the group
    /// as the Dock knows it, for a rename or a change of mode.
    func putInDock(_ group: DockGroup, previous: DockGroup? = nil) throws {
        backupDock()
        var others = tiles(Self.othersKey), apps = tiles(Self.appsKey)
        let oldStacks = Set([stackURL(for: group)] + (previous.map { [stackURL(for: $0)] } ?? []))
        let stackIndex = others.firstIndex { Self.url(of: $0).map(oldStacks.contains) == true }
        let appIndex = apps.firstIndex { Self.url(of: $0).map { isLauncher($0, of: group) } == true }

        // A launcher left by an earlier version gives its place to the stack.
        if let appIndex { apps.remove(at: appIndex) }
        if let stackIndex { others[stackIndex] = stackTile(for: group) } else { others.append(stackTile(for: group)) }
        write(others, Self.othersKey)
        write(apps, Self.appsKey)
    }

    func removeFromDock(_ group: DockGroup) {
        backupDock()
        let stack = stackURL(for: group)
        write(tiles(Self.othersKey).filter { Self.url(of: $0) != stack }, Self.othersKey)
        write(tiles(Self.appsKey).filter { Self.url(of: $0).map { !isLauncher($0, of: group) } ?? true }, Self.appsKey)
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

    /// The Dock reads its tiles only when it starts. It is back in about a
    /// second, with every app and window where it was.
    func restartDock() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        let pid = process.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { if process.isRunning { kill(pid, SIGTERM) } }
    }
}
