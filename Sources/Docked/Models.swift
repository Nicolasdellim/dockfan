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
    var title: String { self == .stack ? L("macOS fan", "Éventail macOS") : L("Docked fan", "Éventail Docked") }
    var subtitle: String {
        self == .stack
            ? L("The Dock’s own animation, beside the Trash. No settings.", "L’animation du Dock, près de la corbeille. Aucun réglage.")
            : L("A tile among your apps. Every setting above applies.", "Une tuile parmi vos apps. Tous les réglages ci-dessus s’appliquent.")
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
    /// One app's icon, chosen among the group's.
    case singleApp = 4
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .stack: L("App stack", "Pile d’apps")
        case .folder: L("Folder", "Dossier")
        case .appGrid: L("Several apps", "Plusieurs apps")
        case .image: L("Photo", "Photo")
        case .singleApp: L("One app", "Une app")
        }
    }
    static func available(for mode: GroupMode) -> [TileStyle] {
        mode == .stack ? [.appGrid, .singleApp, .image, .folder, .stack] : [.appGrid, .singleApp, .image, .folder]
    }
    /// Styles drawn by Docked and set as the icon of the folder or launcher.
    var isComposed: Bool { self == .appGrid || self == .image || self == .singleApp }
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

/// How the fan shows each app's name.
enum FanLabels: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Black pills, as macOS draws them.
    case dark
    /// Pills in the chosen colour.
    case color
    /// Liquid Glass pills.
    case glass
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dark: L("Dark", "Sombre")
        case .color: L("Colour", "Couleur")
        case .glass: L("Glass", "Verre")
        }
    }

    /// Reads the values of earlier versions.
    init(from decoder: Decoder) throws {
        switch try decoder.singleValueContainer().decode(String.self) {
        case "color": self = .color
        case "glass": self = .glass
        default: self = .dark
        }
    }
}

enum HoverEffect: String, Codable, CaseIterable, Identifiable, Sendable {
    case zoom, glow, none
    var id: String { rawValue }
    var title: String {
        switch self {
        case .zoom: L("Zoom", "Zoom")
        case .glow: L("Glow", "Lueur")
        case .none: L("None", "Aucun")
        }
    }
}

enum OpenAnimation: String, Codable, CaseIterable, Identifiable, Sendable {
    case spring, smooth, quick, fade
    var id: String { rawValue }
    var title: String {
        switch self {
        case .spring: L("Bouncy", "Rebond")
        case .smooth: L("Smooth", "Fluide")
        case .quick: L("Quick", "Rapide")
        case .fade: L("Fade", "Fondu")
        }
    }
}

/// Everything about the fan Docked draws.
struct PanelStyle: Codable, Equatable, Sendable {
    var iconSize: Double = 52
    /// The gap between two icons.
    var spacing: Double = 8
    /// How much the fan bends; 0 is straight up.
    var curve: Double = 0.55
    /// Bends to the right as macOS does, or to the left.
    var bendsRight = true
    var shadows = true
    // Names
    var showsLabels = true
    var labels: FanLabels = .dark
    var labelSize: Double = 12.5
    /// Names on the left of the icons, as macOS; or on the right.
    var labelsLeft = true
    /// The colour of colour and glass pills, and of the glow.
    var tint: Finish? = nil
    /// A colour of the user's, `#RRGGBB`, over `tint`.
    var customTint: String? = nil
    // Motion
    var opening: OpenAnimation = .spring
    /// The delay between one icon and the next, in seconds.
    var cascade: Double = 0.022
    var hover: HoverEffect = .zoom

    init() {}

    var tintColor: NSColor? {
        if let customTint, let color = NSColor(hex: customTint) { return color }
        return tint?.colors.0
    }

    /// Whether text on a pill of this colour should be dark.
    var lightPills: Bool {
        guard labels != .dark, let color = tintColor?.usingColorSpace(.sRGB) else { return false }
        return 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent > 0.65
    }

    private enum CodingKeys: String, CodingKey {
        case iconSize = "fanIconSize", spacing = "fanSpacing", curve = "fanCurve", bendsRight, shadows,
             showsLabels, labels = "fanLabels", labelSize, labelsLeft, tint, customTint, opening = "animation", cascade, hover
    }

    /// Reads any earlier version: a missing key keeps its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawLabels = try? c.decodeIfPresent(String.self, forKey: .labels)
        iconSize = try c.decodeIfPresent(Double.self, forKey: .iconSize) ?? 52
        spacing = try c.decodeIfPresent(Double.self, forKey: .spacing) ?? 8
        curve = try c.decodeIfPresent(Double.self, forKey: .curve) ?? 0.55
        bendsRight = try c.decodeIfPresent(Bool.self, forKey: .bendsRight) ?? true
        shadows = try c.decodeIfPresent(Bool.self, forKey: .shadows) ?? true
        showsLabels = try c.decodeIfPresent(Bool.self, forKey: .showsLabels) ?? (rawLabels != "none")
        labels = try c.decodeIfPresent(FanLabels.self, forKey: .labels) ?? .dark
        labelSize = try c.decodeIfPresent(Double.self, forKey: .labelSize) ?? 12.5
        labelsLeft = try c.decodeIfPresent(Bool.self, forKey: .labelsLeft) ?? true
        tint = try c.decodeIfPresent(Finish.self, forKey: .tint)
        customTint = try c.decodeIfPresent(String.self, forKey: .customTint)
        opening = (try? c.decodeIfPresent(OpenAnimation.self, forKey: .opening)) ?? .spring
        cascade = try c.decodeIfPresent(Double.self, forKey: .cascade) ?? 0.022
        hover = (try? c.decodeIfPresent(HoverEffect.self, forKey: .hover)) ?? .zoom
    }
}

/// Ready-made fans. They change the look, never the apps.
struct LookPreset: Identifiable, Sendable {
    let id: String
    let title: String
    let apply: @Sendable (inout PanelStyle) -> Void

    static let all: [LookPreset] = [
        LookPreset(id: "classic", title: L("Classic", "Classique")) { $0 = PanelStyle() },
        LookPreset(id: "glass", title: L("Glass", "Verre")) { $0.labels = .glass; $0.showsLabels = true; $0.tint = nil; $0.customTint = nil; $0.hover = .glow; $0.opening = .smooth },
        LookPreset(id: "ember", title: L("Ember", "Braise")) { $0.labels = .color; $0.showsLabels = true; $0.tint = .ember; $0.customTint = nil; $0.hover = .glow },
        LookPreset(id: "ocean", title: L("Ocean", "Océan")) { $0.labels = .color; $0.showsLabels = true; $0.tint = .ocean; $0.customTint = nil },
        LookPreset(id: "minimal", title: L("Icons only", "Icônes seules")) { $0.showsLabels = false; $0.spacing = 4; $0.curve = 0.3; $0.hover = .zoom },
        LookPreset(id: "big", title: L("Big", "Grand")) { $0.iconSize = 72; $0.spacing = 12; $0.labelSize = 14 },
        LookPreset(id: "straight", title: L("Straight", "Droit")) { $0.curve = 0; $0.opening = .quick; $0.cascade = 0.01 },
    ]
}

extension NSColor {
    convenience init?(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespaces)
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6, let value = UInt32(raw, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format: "#%02X%02X%02X", Int(round(c.redComponent * 255)), Int(round(c.greenComponent * 255)), Int(round(c.blueComponent * 255)))
    }
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
    /// The app for `.singleApp`; the first app when unset.
    var iconApp: UUID?
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
        iconApp = try c.decodeIfPresent(UUID.self, forKey: .iconApp)
        panel = try c.decodeIfPresent(PanelStyle.self, forKey: .panel) ?? PanelStyle()
    }

    /// The app whose icon is the tile's in `.singleApp`.
    var singleApp: AppEntry? { displayedApps.first { $0.id == iconApp } ?? displayedApps.first }

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
