//
//  DevelopmentSnapshots.swift
//  Groupdock
//
//  Renders the editor window to PNG files for development, with sample
//  groups in a temporary folder. It never reads or writes the Dock.
//

import AppKit
import SwiftUI

public enum GroupdockDevelopment {
    /// Edits a group the way the editor does and checks the folder the Dock
    /// would read: one alias per app, the first app newest. Never touches the
    /// Dock. Returns the failures, empty when everything holds.
    @MainActor
    public static func selfTest() -> [String] {
        var failures: [String] = []
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("groupdock-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let apps = ["Music", "Calculator", "Notes"].compactMap { AppEntry(url: URL(fileURLWithPath: "/System/Applications/\($0).app")) }
        let store = GroupStore(root: root)
        store.load()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        store.addGroup()
        guard var group = store.selectedGroup else { return ["no group after addGroup"] }
        // A burst of edits, as typing a name and dragging rows produce.
        group.name = "Test"; store.update(group)
        group.apps = apps; store.update(group)
        group.apps.reverse(); store.update(group)
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))

        let folder = store.service.folder(for: group)
        let items = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }
            .map(\.lastPathComponent)
        let expected = group.apps.map(\.name)
        if items != expected { failures.append("folder order \(items), expected \(expected)") }
        for name in expected {
            let alias = folder.appendingPathComponent(name)
            if (try? URL(resolvingAliasFileAt: alias)) == nil { failures.append("\(name) is not a resolvable alias") }
        }
        let saved = store.service.load()
        if saved.groups.first(where: { $0.id == group.id })?.apps.map(\.name) != expected { failures.append("groups.json not saved in order") }
        return failures
    }

    @MainActor
    public static func renderEditor(to directory: URL) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("groupdock-shots-\(UUID().uuidString)")
        let apps = ["Music", "Calculator", "Notes", "Maps", "Photos", "Preview"].map {
            AppEntry(url: URL(fileURLWithPath: "/System/Applications/\($0).app"))!
        }
        var utilities = DockGroup(name: "Utility", apps: Array(apps.prefix(6)))
        utilities.presentation = .fan
        let creative = DockGroup(name: "Création", apps: Array(apps.suffix(2)))
        let document = GroupDocument(groups: [utilities, creative])
        let service = DockStackService(root: root)
        try service.save(document)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, scheme) in [("editor-dark", NSAppearance.Name.darkAqua), ("editor-light", .aqua)] {
            let store = GroupStore(root: root)
            store.load()
            RunLoop.main.run(until: Date().addingTimeInterval(0.8))
            let view = NSHostingView(rootView: EditorView(store: store))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 700),
                                  styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            window.titlebarAppearsTransparent = true
            window.appearance = NSAppearance(named: scheme)
            window.contentView = view
            window.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(1.2))
            view.layoutSubtreeIfNeeded()
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            try rep.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent("\(name).png"))
            window.orderOut(nil)
        }
        try? FileManager.default.removeItem(at: root)
    }
}
