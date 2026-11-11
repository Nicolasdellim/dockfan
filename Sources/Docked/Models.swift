//
//  Models.swift
//  Docked
//

import AppKit
import Foundation

/// How the Dock shows a stack once it is open.
enum StackPresentation: Int, Codable, CaseIterable, Identifiable, Sendable {
    case automatic = 0, fan = 1, grid = 2, list = 3
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .automatic: L("Automatic", "Automatique")
        case .fan: L("Fan", "Éventail")
        case .grid: L("Grid", "Grille")
        case .list: L("List", "Liste")
        }
    }
    var subtitle: String {
        switch self {
        case .automatic: L("Fan, or a grid for a large group", "Éventail, ou grille si le groupe est grand")
        case .fan: L("The animated arc, as in the Dock", "L’arc animé, comme dans le Dock")
        case .grid: L("A panel of icons", "Un panneau d’icônes")
        case .list: L("A compact list of names", "Une liste compacte de noms")
        }
    }
    var symbol: String {
        switch self {
        case .automatic: "wand.and.stars"
        case .fan: "rectangle.stack"
        case .grid: "square.grid.3x3"
        case .list: "list.bullet"
        }
    }
}

/// How the closed tile looks in the Dock.
enum TileStyle: Int, Codable, CaseIterable, Identifiable, Sendable {
    /// The apps piled on each other, the first one on top (as in the video).
    case stack = 0
    /// A plain folder icon.
    case folder = 1
    var id: Int { rawValue }
    var title: String { self == .stack ? L("App stack", "Pile d’apps") : L("Folder", "Dossier") }
}

/// Order of the apps in the open stack.
enum StackOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    case custom, name
    var id: String { rawValue }
    var title: String { self == .custom ? L("Custom", "Personnalisé") : L("By name", "Par nom") }
    /// The Dock's own `arrangement` value: 3 sorts by date modified (newest
    /// first), which is how the custom order is written; 1 sorts by name.
    var dockArrangement: Int { self == .custom ? 3 : 1 }
}

struct AppEntry: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var path: String
    var bundleIdentifier: String?

    init(id: UUID = UUID(), name: String, path: String, bundleIdentifier: String? = nil) {
        self.id = id; self.name = name; self.path = path; self.bundleIdentifier = bundleIdentifier
    }

    /// An entry for an app on disk, or `nil` when the URL is not an app.
    init?(url: URL) {
        let url = url.resolvingSymlinksInPath()
        guard url.pathExtension.lowercased() == "app", let bundle = Bundle(url: url) else { return nil }
        let name = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
            ?? FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        self.init(name: name, path: url.path, bundleIdentifier: bundle.bundleIdentifier)
    }

    /// The app's current location: its saved path, or wherever Launch
    /// Services finds its bundle identifier if it moved.
    var resolvedURL: URL? {
        if FileManager.default.fileExists(atPath: path) { return URL(fileURLWithPath: path) }
        guard let bundleIdentifier else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    var icon: NSImage {
        if let url = resolvedURL { return NSWorkspace.shared.icon(forFile: url.path) }
        return NSWorkspace.shared.icon(for: .application)
    }
}

struct DockGroup: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var apps: [AppEntry] = []
    var presentation: StackPresentation = .fan
    var tileStyle: TileStyle = .stack
    var order: StackOrder = .custom
    /// Show “Photoshop.app” instead of “Photoshop”, the way the stacks of the
    /// reference video read.
    var showsExtension = false

    init(id: UUID = UUID(), name: String, apps: [AppEntry] = []) {
        self.id = id; self.name = name; self.apps = apps
    }

    /// Apps in the order the open stack shows them, from the Dock upwards.
    var displayedApps: [AppEntry] {
        order == .name
            ? apps.sorted { label(for: $0).localizedStandardCompare(label(for: $1)) == .orderedAscending }
            : apps
    }

    func label(for app: AppEntry) -> String { showsExtension ? app.name + ".app" : app.name }

    /// The folder name, which is what the Dock shows as the stack's label.
    var folderName: String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? L("Group", "Groupe") : cleaned
    }
}

struct GroupDocument: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var groups: [DockGroup] = []
}
