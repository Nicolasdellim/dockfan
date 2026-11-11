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
    var title: String { self == .stack ? "macOS" : "Docked" }
    var subtitle: String {
        self == .stack
            ? L("The Dock’s own stack, beside the Trash. Few options.", "La pile du Dock, près de la corbeille. Peu d’options.")
            : L("Drawn by Docked, among your apps. Everything is yours to set.", "Dessiné par Docked, parmi vos apps. Tout se règle.")
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

/// How a group opens: the choice the editor puts first.
enum PanelLayout: String, Codable, CaseIterable, Identifiable, Sendable {
    case fan, grid, list
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fan: L("Fan", "Éventail")
        case .grid: L("Grid", "Grille")
        case .list: L("List", "Liste")
        }
    }
    var subtitle: String {
        switch self {
        case .fan: L("Icons rise in an arc", "Les icônes montent en arc")
        case .grid: L("A panel of icons", "Un panneau d’icônes")
        case .list: L("Names in a column", "Les noms en colonne")
        }
    }
    var symbol: String {
        switch self {
        case .fan: "rectangle.stack"
        case .grid: "square.grid.3x3"
        case .list: "list.bullet"
        }
    }
    /// The Dock's own presentation for the same view.
    var native: StackPresentation {
        switch self {
        case .fan: .fan
        case .grid: .grid
        case .list: .list
        }
    }

    /// Reads the layouts of earlier versions: icons and tiles are grids now.
    init(from decoder: Decoder) throws {
        switch try decoder.singleValueContainer().decode(String.self) {
        case "fan": self = .fan
        case "list": self = .list
        default: self = .grid
        }
    }
}

/// What the panel and the fan's names are made of.
enum GlassMaterial: String, Codable, CaseIterable, Identifiable, Sendable {
    case liquid, clear, frosted, solid
    var id: String { rawValue }
    var title: String {
        switch self {
        case .liquid: "Liquid Glass"
        case .clear: L("Clear glass", "Verre clair")
        case .frosted: L("Frosted", "Givré")
        case .solid: L("Solid", "Plein")
        }
    }
    var subtitle: String {
        switch self {
        case .liquid: L("macOS 26’s glass", "Le verre de macOS 26")
        case .clear: L("More of the desktop", "Plus de bureau visible")
        case .frosted: L("Soft blur", "Flou doux")
        case .solid: L("An opaque colour", "Une couleur opaque")
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

/// How the fan shows each app's name.
enum FanLabels: String, Codable, CaseIterable, Identifiable, Sendable {
    case pill, glass, none
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pill: L("Pill", "Pastille")
        case .glass: L("Glass", "Verre")
        case .none: L("Hidden", "Masqués")
        }
    }
}

/// Everything about how Docked draws a group when it opens.
struct PanelStyle: Codable, Equatable, Sendable {
    var layout: PanelLayout = .fan
    // Grid
    var columns = 4
    var rows = 2
    var iconSize: Double = 56
    var tiles = false
    var showsTitles = true
    var showsHeader = true
    var hover: HoverEffect = .zoom
    // List
    var listRows = 8
    var listIconSize: Double = 28
    // Fan
    var fanIconSize: Double = 52
    var fanCount = 9
    var fanSpacing: Double = 8
    var fanCurve: Double = 0.55
    var fanLabels: FanLabels = .pill
    // Look
    var material: GlassMaterial = .liquid
    /// The glass's tint; `nil` with no custom colour is untinted.
    var tint: Finish? = nil
    /// A colour of the user's, `#RRGGBB`, over `tint`.
    var customTint: String? = nil
    var tintStrength: Double = 0.45
    var cornerRadius: Double = 26
    var opening: OpenAnimation = .spring

    init() {}

    var perPage: Int {
        switch layout {
        case .fan: max(1, fanCount)
        case .grid: max(1, columns) * max(1, rows)
        case .list: max(1, listRows)
        }
    }

    /// The tint as a colour, from the custom one or the finish.
    var tintColor: NSColor? {
        if let customTint, let color = NSColor(hex: customTint) { return color }
        return tint?.colors.0
    }

    /// Whether text on this glass should be dark.
    var isLight: Bool {
        guard let color = tintColor?.usingColorSpace(.sRGB) else { return false }
        let luminance = 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
        let weight = material == .solid ? 1 : tintStrength
        return luminance > 0.62 && weight > 0.35
    }

    private enum CodingKeys: String, CodingKey {
        case layout, columns, rows, iconSize, tiles, showsTitles, showsHeader, hover, listRows, listIconSize,
             fanIconSize, fanCount, fanSpacing, fanCurve, fanLabels, material, tint, customTint, tintStrength,
             cornerRadius, opening = "animation", clearGlass
    }

    /// Reads any earlier version: a missing key keeps its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawLayout = try c.decodeIfPresent(String.self, forKey: .layout)
        layout = try c.decodeIfPresent(PanelLayout.self, forKey: .layout) ?? .fan
        columns = try c.decodeIfPresent(Int.self, forKey: .columns) ?? 4
        rows = try c.decodeIfPresent(Int.self, forKey: .rows) ?? 2
        iconSize = try c.decodeIfPresent(Double.self, forKey: .iconSize) ?? 56
        tiles = try c.decodeIfPresent(Bool.self, forKey: .tiles) ?? (rawLayout == "tiles")
        showsTitles = try c.decodeIfPresent(Bool.self, forKey: .showsTitles) ?? true
        showsHeader = try c.decodeIfPresent(Bool.self, forKey: .showsHeader) ?? true
        hover = try c.decodeIfPresent(HoverEffect.self, forKey: .hover) ?? .zoom
        listRows = try c.decodeIfPresent(Int.self, forKey: .listRows) ?? 8
        listIconSize = try c.decodeIfPresent(Double.self, forKey: .listIconSize) ?? 28
        fanIconSize = try c.decodeIfPresent(Double.self, forKey: .fanIconSize) ?? 52
        fanCount = try c.decodeIfPresent(Int.self, forKey: .fanCount) ?? 9
        fanSpacing = try c.decodeIfPresent(Double.self, forKey: .fanSpacing) ?? 8
        fanCurve = try c.decodeIfPresent(Double.self, forKey: .fanCurve) ?? 0.55
        fanLabels = try c.decodeIfPresent(FanLabels.self, forKey: .fanLabels) ?? .pill
        let clear = try c.decodeIfPresent(Bool.self, forKey: .clearGlass) ?? false
        material = try c.decodeIfPresent(GlassMaterial.self, forKey: .material) ?? (clear ? .clear : .liquid)
        tint = try c.decodeIfPresent(Finish.self, forKey: .tint)
        customTint = try c.decodeIfPresent(String.self, forKey: .customTint)
        tintStrength = try c.decodeIfPresent(Double.self, forKey: .tintStrength) ?? 0.45
        cornerRadius = try c.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 26
        opening = try c.decodeIfPresent(OpenAnimation.self, forKey: .opening) ?? .spring
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(layout, forKey: .layout); try c.encode(columns, forKey: .columns); try c.encode(rows, forKey: .rows)
        try c.encode(iconSize, forKey: .iconSize); try c.encode(tiles, forKey: .tiles); try c.encode(showsTitles, forKey: .showsTitles)
        try c.encode(showsHeader, forKey: .showsHeader); try c.encode(hover, forKey: .hover); try c.encode(listRows, forKey: .listRows)
        try c.encode(listIconSize, forKey: .listIconSize); try c.encode(fanIconSize, forKey: .fanIconSize)
        try c.encode(fanCount, forKey: .fanCount); try c.encode(fanSpacing, forKey: .fanSpacing); try c.encode(fanCurve, forKey: .fanCurve)
        try c.encode(fanLabels, forKey: .fanLabels); try c.encode(material, forKey: .material)
        try c.encodeIfPresent(tint, forKey: .tint); try c.encodeIfPresent(customTint, forKey: .customTint)
        try c.encode(tintStrength, forKey: .tintStrength); try c.encode(cornerRadius, forKey: .cornerRadius)
        try c.encode(opening, forKey: .opening)
    }
}

/// Ready-made looks, as TinyFolder's presets. They change the look, never
/// the view or the sizes.
struct LookPreset: Identifiable, Sendable {
    let id: String
    let title: String
    let apply: @Sendable (inout PanelStyle) -> Void

    static let all: [LookPreset] = [
        LookPreset(id: "glass", title: L("Glass", "Verre")) { $0.material = .liquid; $0.tint = nil; $0.customTint = nil; $0.cornerRadius = 26; $0.hover = .zoom },
        LookPreset(id: "crystal", title: L("Crystal", "Cristal")) { $0.material = .clear; $0.tint = .snow; $0.customTint = nil; $0.tintStrength = 0.2; $0.cornerRadius = 30; $0.hover = .glow },
        LookPreset(id: "ember", title: L("Ember", "Braise")) { $0.material = .liquid; $0.tint = .ember; $0.customTint = nil; $0.tintStrength = 0.5; $0.cornerRadius = 26; $0.hover = .zoom },
        LookPreset(id: "ocean", title: L("Ocean", "Océan")) { $0.material = .frosted; $0.tint = .ocean; $0.customTint = nil; $0.tintStrength = 0.45; $0.cornerRadius = 22; $0.hover = .glow },
        LookPreset(id: "night", title: L("Night", "Nuit")) { $0.material = .solid; $0.tint = .graphite; $0.customTint = nil; $0.cornerRadius = 18; $0.hover = .glow },
        LookPreset(id: "candy", title: L("Candy", "Bonbon")) { $0.material = .solid; $0.tint = .rose; $0.customTint = nil; $0.cornerRadius = 32; $0.hover = .zoom },
        LookPreset(id: "minimal", title: L("Minimal", "Minimal")) { $0.material = .clear; $0.tint = nil; $0.customTint = nil; $0.cornerRadius = 14; $0.hover = .none; $0.showsHeader = false },
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

    /// The view the user chose, whoever draws it. Setting it keeps the two
    /// renderers in step, so switching between them keeps the view.
    var view: PanelLayout {
        get {
            guard mode == .stack else { return panel.layout }
            switch presentation {
            case .grid: return .grid
            case .list: return .list
            default: return .fan
            }
        }
        set {
            panel.layout = newValue
            presentation = newValue.native
        }
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
