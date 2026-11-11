//
//  FolderPanel.swift
//  Docked
//
//  What a group drawn by Docked shows when it opens: a fan of icons rising
//  from its tile, or a panel of glass with a grid or a list on pages. It
//  opens where the click was, closes on a click elsewhere, on Escape or once
//  an app launches, and never takes the menu bar.
//

import AppKit
import SwiftUI

// MARK: - Layout

/// Sizes for a group, shared by the window and the editor's preview.
struct PanelMetrics {
    let style: PanelStyle
    let count: Int

    static let padding: CGFloat = 18
    static let dots: CGFloat = 22
    static let fanLabelWidth: CGFloat = 190

    var header: CGFloat { style.showsHeader ? 38 : 4 }

    var icon: CGFloat {
        switch style.layout {
        case .fan: CGFloat(style.fanIconSize)
        case .grid: CGFloat(style.iconSize)
        case .list: CGFloat(style.listIconSize)
        }
    }
    var spacing: CGFloat { style.layout == .list ? 4 : style.tiles ? 12 : 10 }
    var cell: CGSize {
        switch style.layout {
        case .fan, .grid:
            style.tiles
                ? CGSize(width: icon + 46, height: icon + (style.showsTitles ? 52 : 34))
                : CGSize(width: icon + 26, height: icon + (style.showsTitles ? 30 : 12))
        case .list: CGSize(width: max(220, icon + 200), height: icon + 12)
        }
    }
    var columns: Int { style.layout == .list ? 1 : max(1, style.columns) }
    var perPage: Int { style.layout == .list ? max(1, style.listRows) : columns * max(1, style.rows) }
    var pages: Int { max(1, Int((Double(count) / Double(perPage)).rounded(.up))) }
    var rows: Int {
        let needed = Int((Double(min(count, perPage)) / Double(columns)).rounded(.up))
        return max(1, pages > 1 ? perPage / columns : needed)
    }
    var usedColumns: Int { pages > 1 ? columns : max(1, min(columns, count)) }
    var gridSize: CGSize {
        CGSize(width: CGFloat(usedColumns) * cell.width + CGFloat(usedColumns - 1) * spacing,
               height: CGFloat(rows) * cell.height + CGFloat(rows - 1) * spacing)
    }

    // Fan
    var fanShown: Int { min(count, max(1, style.fanCount)) }
    var fanStep: CGFloat { CGFloat(style.fanIconSize) + CGFloat(style.fanSpacing) }
    var fanSize: CGSize {
        let n = CGFloat(fanShown)
        let curve = (n - 1) * (n - 1) * CGFloat(style.fanCurve)
        let side = Self.fanLabelWidth + icon / 2 + 24 + curve
        return CGSize(width: side * 2, height: n * fanStep + 24)
    }

    var size: CGSize {
        if style.layout == .fan { return fanSize }
        return CGSize(width: max(200, gridSize.width + Self.padding * 2),
                      height: header + gridSize.height + Self.padding * 2 + (pages > 1 ? Self.dots : 0) - 6)
    }
}

extension OpenAnimation {
    var curve: Animation {
        switch self {
        case .spring: .spring(response: 0.34, dampingFraction: 0.72)
        case .smooth: .spring(response: 0.42, dampingFraction: 0.96)
        case .quick: .easeOut(duration: 0.14)
        case .fade: .easeInOut(duration: 0.22)
        }
    }
}

// MARK: - View

struct FolderPanelView: View {
    let group: DockGroup
    var interactive = true
    /// Open or closed: the view animates between the two itself.
    var opened = true
    var onLaunch: (AppEntry) -> Void = { _ in }
    var onEdit: () -> Void = {}
    @State private var showAll = false

    var body: some View {
        if group.panel.layout == .fan && !showAll {
            FanView(group: group, opened: opened, onLaunch: onLaunch) { withAnimation(group.panel.opening.curve) { showAll = true } }
        } else {
            BoxView(group: group, interactive: interactive, onLaunch: onLaunch, onEdit: onEdit)
                .scaleEffect(opened || group.panel.opening == .fade ? 1 : 0.86, anchor: .bottom)
                .offset(y: opened || group.panel.opening == .fade ? 0 : 16)
                .opacity(opened ? 1 : 0)
                .animation(group.panel.opening.curve, value: opened)
        }
    }
}

/// The fan: the first app against the Dock, each next one higher and a
/// little to the right, its name on the left, springing out one by one.
private struct FanView: View {
    let group: DockGroup
    let opened: Bool
    let onLaunch: (AppEntry) -> Void
    let showAll: () -> Void
    @State private var hovered: UUID?

    var body: some View {
        let style = group.panel
        let metrics = PanelMetrics(style: style, count: group.apps.count)
        let apps = group.displayedApps
        let more = apps.count - metrics.fanShown
        // With more apps than the fan holds, the top place opens them all.
        let shown = Array(apps.prefix(more > 0 ? metrics.fanShown - 1 : metrics.fanShown))
        ZStack(alignment: .bottom) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, app in
                Button { onLaunch(app) } label: { row(label: app.name, lit: hovered == app.id) { icon(app, lit: hovered == app.id) } }
                    .buttonStyle(.plain)
                    .onHover { inside in withAnimation(.easeOut(duration: 0.12)) { hovered = inside ? app.id : (hovered == app.id ? nil : hovered) } }
                    .modifier(Arc(index: index, metrics: metrics, opened: opened, animation: style.opening))
            }
            if more > 0 {
                Button(action: showAll) {
                    row(label: L("\(more + 1) more", "\(more + 1) de plus"), lit: false) {
                        ZStack {
                            Circle().fill(.black.opacity(0.55))
                            Image(systemName: "ellipsis").font(.system(size: metrics.icon * 0.32, weight: .bold)).foregroundStyle(.white)
                        }
                        .frame(width: metrics.icon * 0.8, height: metrics.icon * 0.8)
                        .frame(width: metrics.icon, height: metrics.icon)
                    }
                }
                .buttonStyle(.plain)
                .modifier(Arc(index: shown.count, metrics: metrics, opened: opened, animation: style.opening))
            }
        }
        .frame(width: metrics.fanSize.width, height: metrics.fanSize.height, alignment: .bottom)
    }

    /// Icon centred on the view's axis, name to its left.
    private func row<Icon: View>(label: String, lit: Bool, @ViewBuilder icon: () -> Icon) -> some View {
        let metrics = PanelMetrics(style: group.panel, count: group.apps.count)
        return HStack(spacing: 10) {
            Group {
                if group.panel.fanLabels != .none {
                    Text(label).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                        .foregroundStyle(labelText)
                        .padding(.horizontal, 11).frame(height: 24)
                        .modifier(LabelBackground(style: group.panel, lit: lit))
                }
            }
            .frame(width: PanelMetrics.fanLabelWidth, alignment: .trailing)
            icon()
            Color.clear.frame(width: PanelMetrics.fanLabelWidth + 10)
        }
        .frame(height: metrics.icon)
        .contentShape(Rectangle())
    }

    private var labelText: Color {
        group.panel.fanLabels == .glass && group.panel.isLight ? .black.opacity(0.85) : .white
    }

    private func icon(_ app: AppEntry, lit: Bool) -> some View {
        let size = PanelMetrics(style: group.panel, count: group.apps.count).icon
        return Image(nsImage: app.icon).resizable().interpolation(.high)
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.35), radius: 5, y: 3)
            .scaleEffect(lit && group.panel.hover == .zoom ? 1.12 : 1)
            .background {
                if lit && group.panel.hover == .glow {
                    Circle().fill(Color(nsColor: group.panel.tintColor ?? .white).opacity(0.45)).blur(radius: 14)
                }
            }
    }
}

private struct LabelBackground: ViewModifier {
    let style: PanelStyle
    let lit: Bool

    func body(content: Content) -> some View {
        switch style.fanLabels {
        case .glass:
            content.modifier(PanelGlass(style: style, shape: AnyShape(Capsule())))
        default:
            let tint = style.tintColor.map { Color(nsColor: $0) }
            content.background(Capsule().fill(tint.map { $0.opacity(0.35 + style.tintStrength * 0.5) } ?? Color.black.opacity(lit ? 0.75 : 0.6)))
                .background(Capsule().fill(.black.opacity(0.35)))
                .overlay(Capsule().strokeBorder(.white.opacity(lit ? 0.3 : 0.12), lineWidth: 0.6))
        }
    }
}

/// Where a fan item sits, closed inside the tile, open on the arc.
private struct Arc: ViewModifier {
    let index: Int
    let metrics: PanelMetrics
    let opened: Bool
    let animation: OpenAnimation

    func body(content: Content) -> some View {
        let i = CGFloat(index)
        let curve = CGFloat(metrics.style.fanCurve)
        let x = i * i * curve
        let y = -(i * metrics.fanStep) - 8
        let fade = animation == .fade
        content
            .rotationEffect(.degrees(opened ? Double(i) * 1.6 * Double(curve) : 0), anchor: .center)
            .offset(x: opened ? x : 0, y: opened ? y : (fade ? y : metrics.fanStep))
            .scaleEffect(opened || fade ? 1 : 0.35, anchor: .bottom)
            .opacity(opened ? 1 : 0)
            .animation(animation.curve.delay(opened && animation != .quick ? Double(index) * 0.022 : 0), value: opened)
    }
}

/// A panel of glass with a grid or a list, on pages.
private struct BoxView: View {
    let group: DockGroup
    let interactive: Bool
    let onLaunch: (AppEntry) -> Void
    let onEdit: () -> Void
    @State private var page = 0
    @State private var hovered: UUID?
    @State private var forward = true

    /// A fan showing all its apps opens as a grid.
    private var style: PanelStyle {
        var style = group.panel
        if style.layout == .fan { style.layout = .grid }
        return style
    }
    private var metrics: PanelMetrics { PanelMetrics(style: style, count: group.apps.count) }
    private var light: Bool { style.isLight }

    var body: some View {
        let metrics = metrics
        VStack(spacing: 0) {
            if style.showsHeader { header } else { Color.clear.frame(height: metrics.header) }
            pageView(metrics)
                .frame(width: metrics.gridSize.width, height: metrics.gridSize.height, alignment: .topLeading)
                .clipped()
            if metrics.pages > 1 { dots(metrics) }
        }
        .padding(.horizontal, PanelMetrics.padding)
        .padding(.bottom, PanelMetrics.padding)
        .frame(width: metrics.size.width, height: metrics.size.height, alignment: .top)
        .foregroundStyle(light ? Color.black.opacity(0.85) : Color.white)
        .modifier(PanelGlass(style: style, shape: AnyShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)), native: interactive))
        .environment(\.colorScheme, light ? .light : .dark)
        .onChange(of: group.apps.count) { page = min(page, metrics.pages - 1) }
        .background(PageKeys(enabled: interactive) { delta in turn(delta) })
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(group.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            Spacer(minLength: 8)
            if interactive {
                Button(action: onEdit) {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.primary.opacity(0.08)))
                }
                .buttonStyle(.plain).opacity(0.7).help(L("Edit in Docked", "Modifier dans Docked"))
            }
        }
        .frame(height: 34)
        .padding(.top, 4)
    }

    private func pageView(_ metrics: PanelMetrics) -> some View {
        let apps = group.displayedApps
        let start = min(page, metrics.pages - 1) * metrics.perPage
        let slice = Array(apps[min(start, apps.count)..<min(start + metrics.perPage, apps.count)])
        return ZStack(alignment: .topLeading) {
            grid(slice, metrics)
                .id(page)
                .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 24).onEnded { value in
            if value.translation.width < -30 { turn(1) } else if value.translation.width > 30 { turn(-1) }
        })
    }

    @ViewBuilder private func grid(_ apps: [AppEntry], _ metrics: PanelMetrics) -> some View {
        if style.layout == .list {
            VStack(alignment: .leading, spacing: metrics.spacing) {
                ForEach(apps) { app in listRow(app, metrics) }
            }
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(metrics.cell.width), spacing: metrics.spacing), count: metrics.usedColumns),
                      alignment: .leading, spacing: metrics.spacing) {
                ForEach(apps) { app in cell(app, metrics) }
            }
        }
    }

    private func highlight(_ lit: Bool, base: Double) -> some ShapeStyle {
        if lit && style.hover == .glow, let tint = style.tintColor { return AnyShapeStyle(Color(nsColor: tint).opacity(0.35)) }
        return AnyShapeStyle(Color.primary.opacity(base + (lit && style.hover != .none ? 0.09 : 0)))
    }

    private func cell(_ app: AppEntry, _ metrics: PanelMetrics) -> some View {
        let lit = hovered == app.id
        let tiles = style.tiles
        return Button { onLaunch(app) } label: {
            VStack(spacing: tiles ? 8 : 5) {
                Image(nsImage: app.icon).resizable().interpolation(.high)
                    .frame(width: metrics.icon, height: metrics.icon)
                    .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
                    .scaleEffect(lit && style.hover == .zoom ? 1.1 : 1)
                if style.showsTitles {
                    Text(app.name).font(.system(size: tiles ? 12 : 11, weight: .medium)).lineLimit(1).truncationMode(.tail)
                        .frame(maxWidth: metrics.cell.width - 8)
                }
            }
            .frame(width: metrics.cell.width, height: metrics.cell.height)
            .background(RoundedRectangle(cornerRadius: max(8, style.cornerRadius * 0.6), style: .continuous)
                .fill(highlight(lit, base: tiles ? 0.07 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { inside in withAnimation(.easeOut(duration: 0.12)) { hovered = inside ? app.id : (hovered == app.id ? nil : hovered) } }
        .help(app.name)
    }

    private func listRow(_ app: AppEntry, _ metrics: PanelMetrics) -> some View {
        let lit = hovered == app.id
        return Button { onLaunch(app) } label: {
            HStack(spacing: 10) {
                Image(nsImage: app.icon).resizable().interpolation(.high).frame(width: metrics.icon, height: metrics.icon)
                    .scaleEffect(lit && style.hover == .zoom ? 1.1 : 1)
                Text(app.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(width: metrics.cell.width, height: metrics.cell.height)
            .background(RoundedRectangle(cornerRadius: max(6, style.cornerRadius * 0.4), style: .continuous).fill(highlight(lit, base: 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { inside in withAnimation(.easeOut(duration: 0.1)) { hovered = inside ? app.id : (hovered == app.id ? nil : hovered) } }
    }

    private func dots(_ metrics: PanelMetrics) -> some View {
        HStack(spacing: 7) {
            ForEach(0..<metrics.pages, id: \.self) { index in
                Circle().fill(.primary.opacity(index == page ? 0.85 : 0.25))
                    .frame(width: 6, height: 6)
                    .onTapGesture { go(to: index) }
            }
        }
        .frame(height: PanelMetrics.dots)
        .padding(.top, 6)
    }

    private func turn(_ delta: Int) { go(to: page + delta) }

    private func go(to index: Int) {
        let target = max(0, min(metrics.pages - 1, index))
        guard target != page else { return }
        forward = target > page
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { page = target }
    }
}

/// The panel's material: Liquid Glass (regular or clear) on macOS 26, a
/// blur, or a solid colour. The editor's preview never uses the system glass,
/// which only draws in a live window over the desktop.
struct PanelGlass: ViewModifier {
    let style: PanelStyle
    let shape: AnyShape
    var native = true

    func body(content: Content) -> some View {
        let tintColor = style.tintColor.map { Color(nsColor: $0) }
        let tint = tintColor?.opacity(style.tintStrength)
        switch style.material {
        case .solid:
            let base = style.tintColor ?? Finish.graphite.colors.0
            let bottom = base.blended(withFraction: 0.35, of: .black) ?? base
            content
                .background(shape.fill(LinearGradient(colors: [Color(nsColor: base), Color(nsColor: bottom)], startPoint: .top, endPoint: .bottom)))
                .overlay(shape.stroke(.white.opacity(0.18), lineWidth: 0.8))
                .clipShape(shape)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        case .liquid, .clear:
            if #available(macOS 26.0, *), native {
                content.glassEffect(style.material == .clear ? Glass.clear.tint(tint) : Glass.regular.tint(tint), in: shape)
            } else {
                drawn(content, tint: tint, thin: style.material == .clear)
            }
        case .frosted:
            drawn(content, tint: tint, thin: false)
        }
    }

    private func drawn(_ content: Content, tint: Color?, thin: Bool) -> some View {
        content
            .background(shape.fill(tint ?? .white.opacity(0.06)))
            .background(shape.fill(thin ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial)))
            .background(shape.fill(.black.opacity(thin ? 0.05 : 0.18)))
            .overlay(shape.stroke(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom), lineWidth: 0.8))
            .clipShape(shape)
            .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
    }
}

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Arrow keys and the scroll wheel turn pages.
private struct PageKeys: NSViewRepresentable {
    let enabled: Bool
    let turn: (Int) -> Void

    final class Coordinator {
        var monitor: Any?
        var turn: (Int) -> Void = { _ in }
        var lastScroll = Date.distantPast
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        guard enabled else { return view }
        let coordinator = context.coordinator
        coordinator.turn = turn
        coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) { [weak view] event in
            guard let window = view?.window, event.window === window else { return event }
            if event.type == .keyDown {
                switch event.keyCode {
                case 123: coordinator.turn(-1); return nil      // ←
                case 124: coordinator.turn(1); return nil       // →
                default: return event
                }
            }
            let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? -event.scrollingDeltaX : -event.scrollingDeltaY
            guard abs(delta) > 2, Date().timeIntervalSince(coordinator.lastScroll) > 0.45 else { return nil }
            coordinator.lastScroll = Date()
            coordinator.turn(delta > 0 ? 1 : -1)
            return nil
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) { context.coordinator.turn = turn }
}

// MARK: - Window

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Opens and closes the panel of one folder at a time.
@MainActor
final class FolderPanelController {
    private var panel: FloatingPanel?
    private var shownGroup: UUID?
    private var monitors: [Any] = []
    /// When a click outside closed the panel: a click on the folder's own
    /// tile closes it first, then its URL arrives and must not reopen it.
    private var closedByClick: (group: UUID, at: Date)?

    var onEdit: (UUID) -> Void = { _ in }

    func toggle(_ group: DockGroup) {
        if shownGroup == group.id { close(); return }
        if let closed = closedByClick, closed.group == group.id, Date().timeIntervalSince(closed.at) < 0.8 {
            closedByClick = nil
            return
        }
        show(group)
    }

    func show(_ group: DockGroup) {
        close()
        guard !group.apps.isEmpty else { return }
        var size = PanelMetrics(style: group.panel, count: group.apps.count).size
        if group.panel.layout == .fan {
            // Room for the grid the fan's last place opens.
            var grid = group.panel; grid.layout = .grid
            let box = PanelMetrics(style: grid, count: group.apps.count).size
            size = CGSize(width: max(size.width, box.width), height: max(size.height, box.height))
        }
        let margin: CGFloat = 40   // room for the glass's shadow
        let frame = Self.frame(for: CGSize(width: size.width + margin * 2, height: size.height + margin * 2), inset: margin)

        let panel = FloatingPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        let id = group.id
        let root = PanelHost(group: group, edge: Self.dockEdge, onLaunch: { [weak self] app in self?.launch(app) },
                             onEdit: { [weak self] in self?.close(); self?.onEdit(id) })
            .padding(margin)
        panel.contentView = NSHostingView(rootView: root)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        shownGroup = group.id
        install()
    }

    func close() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        shownGroup = nil
    }

    private func launch(_ app: AppEntry) {
        close()
        guard let url = app.resolvedURL else { NSSound.beep(); return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private func install() {
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let id = self.shownGroup else { return }
                self.closedByClick = (id, Date())
                self.close()
            }
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard event.keyCode == 53 else { return event }     // Escape
            MainActor.assumeIsolated { self?.close() }
            return nil
        }) { monitors.append(monitor) }
    }

    // MARK: Placement

    enum Edge { case bottom, left, right }

    static var dockEdge: Edge {
        switch UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") {
        case "left": .left
        case "right": .right
        default: .bottom
        }
    }

    /// Above the click for a bottom Dock, beside it for a side one, inside
    /// the screen's visible frame.
    private static func frame(for size: CGSize, inset: CGFloat) -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let gap: CGFloat = 10 - inset
        var origin: NSPoint
        switch dockEdge {
        case .bottom: origin = NSPoint(x: mouse.x - size.width / 2, y: visible.minY + gap)
        case .left: origin = NSPoint(x: visible.minX + gap, y: mouse.y - size.height / 2)
        case .right: origin = NSPoint(x: visible.maxX - size.width - gap, y: mouse.y - size.height / 2)
        }
        origin.x = min(max(origin.x, visible.minX - inset + 6), visible.maxX - size.width + inset - 6)
        origin.y = min(max(origin.y, visible.minY - inset + 6), visible.maxY - size.height + inset - 6)
        return NSRect(origin: origin, size: size)
    }
}

/// The view with its opening, run once the window is up.
private struct PanelHost: View {
    let group: DockGroup
    let edge: FolderPanelController.Edge
    let onLaunch: (AppEntry) -> Void
    let onEdit: () -> Void
    @State private var open = false

    var body: some View {
        FolderPanelView(group: group, opened: open, onLaunch: onLaunch, onEdit: onEdit)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge == .bottom ? .bottom : .center)
            .onAppear { DispatchQueue.main.async { open = true } }
    }
}
