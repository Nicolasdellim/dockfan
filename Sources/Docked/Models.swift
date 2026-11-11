//
//  Models.swift
//  Docked
//

import AppKit
import Foundation

// MARK: - Modes

/// What a group is in the Dock.
enum GroupMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// A native Dock stack beside the Trash: the Dock's own fan, grid or list.
    case stack
    /// A tile among the apps that opens Docked's own glass panel.
    case folder
    var id: String { rawValue }
    var title: String { self == .stack ? L("Stack", "Pile") : L("Folder", "Dossier") }
    var subtitle: String {
        self == .stack
            ? L("The Dock’s native fan", "L’éventail natif du Dock")
            : L("A glass panel, among apps", "Panneau en verre, parmi les apps")
    }
    var symbol: String { self == .stack ? "rectangle.stack" : "square.grid.2x2" }
}

/// How a native stack opens.
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

/// How the group's tile looks in the Dock.
enum TileStyle: Int, Codable, CaseIterable, Identifiable, Sendable {
    /// The apps piled on each other, the first on top (stacks only).
    case stack = 0
    /// A plain folder icon (stacks only).
    case folder = 1
    /// The group's apps in a small grid on a background: the apps become the icon.
    case appGrid = 2
    /// A picture of the user's.
    case image = 3
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .stack: L("App stack", "Pile d’apps")
        case .folder: L("Folder", "Dossier")
        case .appGrid: L("App grid", "Grille d’apps")
        case .image: L("Picture", "Image")
        }
    }
    static func available(for mode: GroupMode) -> [TileStyle] {
        mode == .stack ? [.stack, .appGrid, .image, .folder] : [.appGrid, .image]
    }
    /// Styles drawn by Docked and set as the icon of the folder or launcher.
    var isComposed: Bool { self == .appGrid || self == .image }
}

/// Order of the apps.
enum StackOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    case custom, name
    var id: String { rawValue }
    var title: String { self == .custom ? L("Custom", "Personnalisé") : L("By name", "Par nom") }
    /// The Dock's own `arrangement` value: 3 sorts by date modified (newest
    /// first), which is how the custom order is written; 1 sorts by name.
    var dockArrangement: Int { self == .custom ? 3 : 1 }
}

// MARK: - Looks

/// A background for a composed icon or a tint for the panel.
enum Finish: String, Codable, CaseIterable, Identifiable, Sendable {
    case glass, graphite, ember, ocean, lagoon, mint, rose, violet, sunset, snow
    var id: String { rawValue }
    var title: String {
        switch self {
        case .glass: L("Glass", "Verre")
        case .graphite: L("Graphite", "Graphite")
        case .ember: L("Ember", "Braise")
        case .ocean: L("Ocean", "Océan")
        case .lagoon: L("Lagoon", "Lagon")
        case .mint: L("Mint", "Menthe")
        case .rose: L("Rose", "Rose")
        case .violet: L("Violet", "Violet")
        case .sunset: L("Sunset", "Couchant")
        case .snow: L("Snow", "Neige")
        }
    }
    /// Top and bottom colours, in sRGB.
    var colors: (NSColor, NSColor) {
        func c(_ r: Double, _ g: Double, _ b: Double) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }
        switch self {
        case .glass: return (c(0.78, 0.84, 0.95), c(0.50, 0.60, 0.80))
        case .graphite: return (c(0.26, 0.27, 0.30), c(0.08, 0.085, 0.10))
        case .ember: return (c(1.0, 0.64, 0.40), c(0.86, 0.33, 0.20))
        case .ocean: return (c(0.36, 0.62, 1.0), c(0.12, 0.30, 0.86))
        case .lagoon: return (c(0.45, 0.88, 0.92), c(0.10, 0.55, 0.70))
        case .mint: return (c(0.62, 0.93, 0.74), c(0.16, 0.62, 0.45))
        case .rose: return (c(1.0, 0.66, 0.78), c(0.88, 0.32, 0.52))
        case .violet: return (c(0.72, 0.60, 1.0), c(0.40, 0.24, 0.84))
        case .sunset: return (c(1.0, 0.80, 0.40), c(0.95, 0.38, 0.40))
        case .snow: return (c(0.99, 0.99, 1.0), c(0.86, 0.88, 0.92))
        }
    }
    var isLight: Bool { self == .snow || self == .glass }
}

/// How the folder panel lays its apps out.
enum PanelLayout: String, Codable, CaseIterable, Identifiable, Sendable {
    case icons, tiles, list
    var id: String { rawValue }
    var title: String {
        switch self {
        case .icons: L("Icons", "Icônes")
        case .tiles: L("Tiles", "Tuiles")
        case .list: L("List", "Liste")
        }
    }
    var symbol: String {
        switch self {
        case .icons: "square.grid.3x3"
        case .tiles: "square.grid.2x2"
        case .list: "list.bullet"
        }
    }
}

/// The folder panel's settings.
struct PanelStyle: Codable, Equatable, Sendable {
    var layout: PanelLayout = .icons
    var columns = 4
    var rows = 2
    var iconSize: Double = 56
    var showsTitles = true
    /// The glass's tint; `nil` is clear glass.
    var tint: Finish? = nil
    /// Clear glass lets more of the desktop through.
    var clearGlass = false

    var perPage: Int { layout == .list ? rows * 3 : columns * rows }
}

// MARK: - Apps

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

// MARK: - Group

struct DockGroup: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var apps: [AppEntry] = []
    var mode: GroupMode = .stack
    var presentation: StackPresentation = .fan
    var tileStyle: TileStyle = .stack
    var order: StackOrder = .custom
    /// Show “Photoshop.app” instead of “Photoshop” in a stack.
    var showsExtension = false
    /// Icon size in a stack's grid; 0 lets the Dock choose.
    var stackGridIconSize: Double = 0
    /// Background of a composed icon.
    var iconFinish: Finish = .glass
    /// 2 for a 2 × 2 grid of apps, 3 for 3 × 3.
    var iconGrid = 2
    /// The picture for `.image`, a file in Docked's Images folder.
    var iconImage: String?
    var panel = PanelStyle()

    init(id: UUID = UUID(), name: String, apps: [AppEntry] = []) {
        self.id = id; self.name = name; self.apps = apps
    }

    /// Reads any earlier version of the file: a key it did not have keeps
    /// its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        apps = try c.decodeIfPresent([AppEntry].self, forKey: .apps) ?? []
        mode = try c.decodeIfPresent(GroupMode.self, forKey: .mode) ?? .stack
        presentation = try c.decodeIfPresent(StackPresentation.self, forKey: .presentation) ?? .fan
        tileStyle = try c.decodeIfPresent(TileStyle.self, forKey: .tileStyle) ?? .stack
        order = try c.decodeIfPresent(StackOrder.self, forKey: .order) ?? .custom
        showsExtension = try c.decodeIfPresent(Bool.self, forKey: .showsExtension) ?? false
        stackGridIconSize = try c.decodeIfPresent(Double.self, forKey: .stackGridIconSize) ?? 0
        iconFinish = try c.decodeIfPresent(Finish.self, forKey: .iconFinish) ?? .glass
        iconGrid = try c.decodeIfPresent(Int.self, forKey: .iconGrid) ?? 2
        iconImage = try c.decodeIfPresent(String.self, forKey: .iconImage)
        panel = try c.decodeIfPresent(PanelStyle.self, forKey: .panel) ?? PanelStyle()
    }

    /// Apps in the order they show, from the Dock upwards in a stack, from
    /// the first page in a folder.
    var displayedApps: [AppEntry] {
        order == .name
            ? apps.sorted { label(for: $0).localizedStandardCompare(label(for: $1)) == .orderedAscending }
            : apps
    }

    func label(for app: AppEntry) -> String { mode == .stack && showsExtension ? app.name + ".app" : app.name }

    /// A tile style the mode allows: switching a stack with a pile to a
    /// folder turns its icon into the app grid.
    var effectiveTileStyle: TileStyle {
        TileStyle.available(for: mode).contains(tileStyle) ? tileStyle : .appGrid
    }

    /// The folder name, which is what the Dock shows as the label.
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
