//
//  FolderPanel.swift
//  Docked
//
//  The panel a folder opens above its Dock tile: the group's apps on pages of
//  Liquid Glass. It opens where the click was, closes on a click elsewhere,
//  on Escape or once an app launches, and never takes the menu bar.
//

import AppKit
import SwiftUI

// MARK: - Layout

/// Sizes of the panel for a group, shared by the panel and its preview.
struct PanelMetrics {
    let style: PanelStyle
    let count: Int

    static let padding: CGFloat = 18
    static let header: CGFloat = 34
    static let dots: CGFloat = 22

    var icon: CGFloat {
        switch style.layout {
        case .icons: CGFloat(style.iconSize)
        case .tiles: CGFloat(style.iconSize) * 0.9
        case .list: 30
        }
    }
    var spacing: CGFloat { style.layout == .list ? 4 : style.layout == .tiles ? 12 : 10 }
    var cell: CGSize {
        switch style.layout {
        case .icons: CGSize(width: icon + 26, height: icon + (style.showsTitles ? 30 : 12))
        case .tiles: CGSize(width: icon + 46, height: icon + (style.showsTitles ? 52 : 34))
        case .list: CGSize(width: 250, height: 40)
        }
    }
    var columns: Int { style.layout == .list ? 1 : max(1, style.columns) }
    var perPage: Int { style.layout == .list ? max(1, style.rows) * 3 : columns * max(1, style.rows) }
    var pages: Int { max(1, Int((Double(count) / Double(perPage)).rounded(.up))) }
    /// Rows the panel shows: all of a page, or fewer when one page is not full.
    var rows: Int {
        let perRow = columns
        let needed = Int((Double(min(count, perPage)) / Double(perRow)).rounded(.up))
        return max(1, pages > 1 ? perPage / perRow : needed)
    }
    var usedColumns: Int { pages > 1 ? columns : max(1, min(columns, count)) }
    var gridSize: CGSize {
        CGSize(width: CGFloat(usedColumns) * cell.width + CGFloat(usedColumns - 1) * spacing,
               height: CGFloat(rows) * cell.height + CGFloat(rows - 1) * spacing)
    }
    var size: CGSize {
        CGSize(width: max(220, gridSize.width + Self.padding * 2),
               height: Self.header + gridSize.height + Self.padding * 2 + (pages > 1 ? Self.dots : 0) - 6)
    }
}

// MARK: - View

struct FolderPanelView: View {
    let group: DockGroup
    var interactive = true
    var onLaunch: (AppEntry) -> Void = { _ in }
    var onEdit: () -> Void = {}
    @State private var page = 0
    @State private var hovered: UUID?
    @State private var forward = true

    private var metrics: PanelMetrics { PanelMetrics(style: group.panel, count: group.apps.count) }
    private var radius: CGFloat { 26 }
    private var lightGlass: Bool { group.panel.tint?.isLight == true }

    var body: some View {
        let metrics = metrics
        VStack(spacing: 0) {
            header
            pageView(metrics)
                .frame(width: metrics.gridSize.width, height: metrics.gridSize.height, alignment: .topLeading)
                .clipped()
            if metrics.pages > 1 { dots(metrics) }
        }
        .padding(.horizontal, PanelMetrics.padding)
        .padding(.bottom, PanelMetrics.padding)
        .frame(width: metrics.size.width, height: metrics.size.height, alignment: .top)
        .foregroundStyle(lightGlass ? Color.black.opacity(0.85) : Color.white)
        .modifier(PanelGlass(style: group.panel, radius: radius, native: interactive))
        .environment(\.colorScheme, lightGlass ? .light : .dark)
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
                .buttonStyle(.plain).foregroundStyle(.secondary).help(L("Edit in Docked", "Modifier dans Docked"))
            }
        }
        .frame(height: PanelMetrics.header)
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
        if group.panel.layout == .list {
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

    private func cell(_ app: AppEntry, _ metrics: PanelMetrics) -> some View {
        let lit = hovered == app.id
        let tiles = group.panel.layout == .tiles
        return Button { onLaunch(app) } label: {
            VStack(spacing: tiles ? 8 : 5) {
                Image(nsImage: app.icon).resizable().interpolation(.high)
                    .frame(width: metrics.icon, height: metrics.icon)
                    .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
                    .scaleEffect(lit && !tiles ? 1.08 : 1)
                if group.panel.showsTitles {
                    Text(app.name).font(.system(size: tiles ? 12 : 11, weight: .medium)).lineLimit(1).truncationMode(.tail)
                        .frame(maxWidth: metrics.cell.width - 8)
                }
            }
            .frame(width: metrics.cell.width, height: metrics.cell.height)
            .background(
                RoundedRectangle(cornerRadius: tiles ? 18 : 14, style: .continuous)
                    .fill(.primary.opacity(tiles ? (lit ? 0.14 : 0.07) : (lit ? 0.10 : 0)))
            )
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
                Image(nsImage: app.icon).resizable().interpolation(.high).frame(width: 28, height: 28)
                Text(app.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(width: metrics.cell.width, height: metrics.cell.height)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.primary.opacity(lit ? 0.10 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .onHover { inside in hovered = inside ? app.id : (hovered == app.id ? nil : hovered) }
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

/// Liquid Glass on macOS 26, a material before it and in the editor's
/// preview (the system glass only draws in a live window over the desktop).
struct PanelGlass: ViewModifier {
    let style: PanelStyle
    let radius: CGFloat
    var native = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let tint = style.tint.map { Color(nsColor: $0.colors.0).opacity(style.clearGlass ? 0.30 : 0.45) }
        if #available(macOS 26.0, *), native {
            content.glassEffect(style.clearGlass ? Glass.clear.tint(tint) : Glass.regular.tint(tint), in: shape)
        } else {
            content
                .background(shape.fill(tint ?? .white.opacity(0.06)))
                .background(shape.fill(style.clearGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial)))
                .background(shape.fill(.black.opacity(style.clearGlass ? 0.05 : 0.18)))
                .overlay(shape.strokeBorder(.white.opacity(0.22), lineWidth: 0.8))
                .clipShape(shape)
                .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
        }
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
        let size = PanelMetrics(style: group.panel, count: group.apps.count).size
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

/// The panel with its opening: it grows out of the Dock, as a stack does.
private struct PanelHost: View {
    let group: DockGroup
    let edge: FolderPanelController.Edge
    let onLaunch: (AppEntry) -> Void
    let onEdit: () -> Void
    @State private var open = false

    var body: some View {
        FolderPanelView(group: group, onLaunch: onLaunch, onEdit: onEdit)
            .scaleEffect(open ? 1 : 0.86, anchor: anchor)
            .offset(x: open ? 0 : edge == .left ? -14 : edge == .right ? 14 : 0, y: open ? 0 : edge == .bottom ? 18 : 0)
            .opacity(open ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { open = true } }
    }

    private var anchor: UnitPoint {
        switch edge {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }
}
