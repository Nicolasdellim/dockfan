//
//  FolderPanel.swift
//  Dockfan
//
//  The fan Dockfan draws above a group's tile: its apps rising one by one in
//  an arc, each with its name. It opens where the click was, closes on a
//  click elsewhere, on Escape or once an app launches, and never takes the
//  menu bar.
//

import AppKit
import SwiftUI

// MARK: - Layout

/// The fan's sizes, shared by the window and the editor's preview.
struct PanelMetrics {
    let style: PanelStyle
    let count: Int

    static let labelWidth: CGFloat = 200

    var icon: CGFloat { CGFloat(style.iconSize) }
    var step: CGFloat { icon + CGFloat(style.spacing) }
    /// How far right (or left) item `index` sits.
    func drift(_ index: Int) -> CGFloat {
        let i = CGFloat(index)
        return i * i * CGFloat(style.curve) * (icon / 52) * (style.bendsRight ? 1 : -1)
    }
    var size: CGSize {
        let n = max(1, count)
        let reach = abs(drift(n - 1))
        let side = Self.labelWidth + icon / 2 + 24 + reach
        return CGSize(width: side * 2, height: CGFloat(n) * step + 30)
    }

    /// The same fan, smaller if needed so it fits in `height`.
    static func fitting(_ style: PanelStyle, count: Int, height: CGFloat) -> PanelStyle {
        let metrics = PanelMetrics(style: style, count: count)
        guard metrics.size.height > height, count > 0 else { return style }
        // Height is count × step + 30: scale the step to what is left.
        var fitted = style
        let ratio = max(0.2, (height - 30) / (CGFloat(count) * metrics.step))
        fitted.iconSize = max(16, style.iconSize * ratio)
        fitted.spacing = style.spacing * ratio
        return fitted
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

/// The first app against the Dock, each next one higher and drifting
/// sideways, its name beside it, springing out one after the other.
struct FolderPanelView: View {
    let group: DockGroup
    var interactive = true
    /// Open or closed: the view animates between the two itself.
    var opened = true
    var onLaunch: (AppEntry) -> Void = { _ in }
    var onEdit: () -> Void = {}
    @State private var hovered: UUID?

    private var style: PanelStyle { group.panel }

    var body: some View {
        let metrics = PanelMetrics(style: style, count: group.apps.count)
        ZStack(alignment: .bottom) {
            ForEach(Array(group.displayedApps.enumerated()), id: \.element.id) { index, app in
                Button { onLaunch(app) } label: { row(app, metrics: metrics) }
                    .buttonStyle(.plain)
                    .allowsHitTesting(interactive)
                    .onHover { inside in
                        withAnimation(.easeOut(duration: 0.12)) { hovered = inside ? app.id : (hovered == app.id ? nil : hovered) }
                    }
                    .modifier(Arc(index: index, metrics: metrics, opened: opened))
            }
        }
        .frame(width: metrics.size.width, height: metrics.size.height, alignment: .bottom)
        .environment(\.colorScheme, .dark)
    }

    /// The icon on the view's axis, the name on its chosen side.
    private func row(_ app: AppEntry, metrics: PanelMetrics) -> some View {
        let lit = hovered == app.id
        // The name's column keeps its width even when names are hidden, so
        // the icons stay centred above the tile.
        let label = ZStack(alignment: style.labelsLeft ? .trailing : .leading) {
            Color.clear
            if style.showsLabels {
                Text(app.name).font(.system(size: style.labelSize, weight: .semibold)).lineLimit(1)
                    .foregroundStyle(style.lightPills ? Color.black.opacity(0.85) : .white)
                    .padding(.horizontal, style.labelSize * 0.85).frame(height: style.labelSize * 1.95)
                    .modifier(PillBackground(style: style, lit: lit, native: interactive))
            }
        }
        .frame(width: PanelMetrics.labelWidth, alignment: style.labelsLeft ? .trailing : .leading)
        return HStack(spacing: 10) {
            if style.labelsLeft { label } else { Color.clear.frame(width: PanelMetrics.labelWidth) }
            icon(app, lit: lit, size: metrics.icon)
            if style.labelsLeft { Color.clear.frame(width: PanelMetrics.labelWidth) } else { label }
        }
        .frame(height: metrics.icon)
        .contentShape(Rectangle())
    }

    private func icon(_ app: AppEntry, lit: Bool, size: CGFloat) -> some View {
        Image(nsImage: app.icon).resizable().interpolation(.high)
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(style.shadows ? 0.38 : 0), radius: size * 0.1, y: size * 0.06)
            .scaleEffect(lit && style.hover == .zoom ? 1.12 : 1)
            .background {
                if lit && style.hover == .glow {
                    Circle().fill(Color(nsColor: style.tintColor ?? .white).opacity(0.5)).blur(radius: size * 0.28)
                }
            }
    }
}

private struct PillBackground: ViewModifier {
    let style: PanelStyle
    let lit: Bool
    /// The system glass only draws in a live window, not in the preview.
    var native = true

    func body(content: Content) -> some View {
        let tint = Color(nsColor: style.tintColor ?? NSColor(white: 0.3, alpha: 1))
        switch style.labels {
        case .dark:
            content
                .background(Capsule().fill(.black.opacity(lit ? 0.85 : 0.72)))
                .overlay(Capsule().strokeBorder(.white.opacity(lit ? 0.28 : 0.12), lineWidth: 0.6))
        case .color:
            content
                .background(Capsule().fill(LinearGradient(colors: [tint, tint.opacity(0.82)], startPoint: .top, endPoint: .bottom)))
                .overlay(Capsule().strokeBorder(.white.opacity(lit ? 0.45 : 0.2), lineWidth: 0.6))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        case .glass:
            if #available(macOS 26.0, *), native {
                content.glassEffect(Glass.regular.tint(style.tintColor.map { Color(nsColor: $0).opacity(0.45) }), in: Capsule())
            } else {
                content
                    .background(Capsule().fill(style.tintColor.map { Color(nsColor: $0).opacity(0.35) } ?? .white.opacity(0.08)))
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.6))
            }
        }
    }
}

/// Where a fan item sits: closed inside the tile, open on the arc.
private struct Arc: ViewModifier {
    let index: Int
    let metrics: PanelMetrics
    let opened: Bool

    func body(content: Content) -> some View {
        let style = metrics.style
        let x = metrics.drift(index)
        let y = -(CGFloat(index) * metrics.step) - 8
        let fade = style.opening == .fade
        let tilt = Double(index) * 1.6 * style.curve * (style.bendsRight ? 1 : -1)
        content
            .rotationEffect(.degrees(opened ? tilt : 0), anchor: .center)
            .offset(x: opened ? x : 0, y: opened || fade ? y : metrics.step)
            .scaleEffect(opened || fade ? 1 : 0.35, anchor: .bottom)
            .opacity(opened ? 1 : 0)
            .animation(style.opening.curve.delay(opened ? Double(index) * style.cascade : 0), value: opened)
    }
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
        // A long group shrinks to fit the screen above the Dock.
        var group = group
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        group.panel = PanelMetrics.fitting(group.panel, count: group.apps.count, height: (screen?.visibleFrame.height ?? 800) - 60)
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
