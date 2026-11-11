//
//  StackPreview.swift
//  Docked
//
//  A picture of what the Dock will show. The real stack is macOS's own; this
//  only helps choose apps, order and presentation before applying.
//

import SwiftUI

struct StackPreview: View {
    let group: DockGroup
    var image: NSImage? = nil
    @Binding var expanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let iconSize: CGFloat = 46
    private let step: CGFloat = 54
    private let labelWidth: CGFloat = 200

    private var apps: [AppEntry] { group.displayedApps }
    /// How the Dock resolves “Automatique”: a fan while it fits, a grid after.
    private var presentation: StackPresentation {
        group.presentation == .automatic ? (apps.count > 9 ? .grid : .fan) : group.presentation
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Backdrop()
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if !apps.isEmpty {
                        if group.mode == .folder { folderPanel(fitting: proxy.size) } else { openContent.frame(maxWidth: .infinity) }
                    }
                    dock.padding(.bottom, 24)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Brand.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Brand.radius, style: .continuous).strokeBorder(Brand.hairline))
    }

    // MARK: Folder

    /// The real panel, scaled down when the stage is smaller than it.
    private func folderPanel(fitting space: CGSize) -> some View {
        let size = PanelMetrics(style: group.panel, count: apps.count).size
        let scale = min(1, (space.width - 40) / size.width, (space.height - 170) / size.height)
        return FolderPanelView(group: group, interactive: false, opened: expanded)
            .frame(width: size.width, height: size.height, alignment: .bottom)
            .scaleEffect(max(0.3, scale), anchor: .bottom)
            .frame(width: size.width * max(0.3, scale), height: size.height * max(0.3, scale))
            .padding(.bottom, group.panel.layout == .fan ? 18 : 14)
            .frame(maxWidth: .infinity)
    }

    // MARK: Open stack

    @ViewBuilder private var openContent: some View {
        switch presentation {
        case .grid, .list: panel
        default: fan
        }
    }

    /// The fan rises from the tile, bending a little to the right and
    /// tilting as it goes, each name in a pill on the left of its icon.
    private var fan: some View {
        let shown = Array(apps.prefix(maxFanItems).enumerated())
        let count = shown.count
        return ZStack(alignment: .bottom) {
            ForEach(shown, id: \.element.id) { index, app in
                fanRow(label: group.label(for: app)) {
                    Image(nsImage: app.icon).resizable().interpolation(.high).frame(width: iconSize, height: iconSize)
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                }
                .modifier(FanPlacement(index: index, step: step, expanded: expanded, reduceMotion: reduceMotion))
            }
            fanRow(label: L("Open in Finder", "Ouvrir dans le Finder")) {
                Circle().fill(Color.black.opacity(0.45))
                    .overlay(Circle().strokeBorder(.white.opacity(0.15)))
                    .overlay(Image(systemName: "arrowshape.turn.up.right.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white))
                    .frame(width: 34, height: 34).frame(width: iconSize, height: iconSize)
            }
            .modifier(FanPlacement(index: count, step: step, expanded: expanded, reduceMotion: reduceMotion))
        }
        .frame(height: CGFloat(count + 1) * step + 12, alignment: .bottom)
        .padding(.bottom, 4)
    }

    /// The Dock shows as many as fit on screen; the preview keeps it readable.
    private var maxFanItems: Int { 9 }

    private func fanRow<Icon: View>(label: String, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.42)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
                .frame(width: labelWidth, alignment: .trailing)
            icon()
        }
        // The icon column sits on the tile's centre line.
        .offset(x: -(labelWidth + 8) / 2)
    }

    /// Grid and list both open as a rounded panel above the tile.
    private var panel: some View {
        let shown = Array(apps.prefix(presentation == .grid ? 15 : 8))
        return VStack(alignment: .leading, spacing: 12) {
            if presentation == .grid {
                let side = group.stackGridIconSize > 0 ? CGFloat(group.stackGridIconSize) * 0.75 : 46
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(side + 30), spacing: 6), count: min(5, max(1, shown.count))), spacing: 12) {
                    ForEach(shown) { app in
                        VStack(spacing: 5) {
                            Image(nsImage: app.icon).resizable().frame(width: side, height: side)
                            Text(group.label(for: app)).font(.system(size: 10.5)).foregroundStyle(.white).lineLimit(1)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(shown) { app in
                        HStack(spacing: 9) {
                            Image(nsImage: app.icon).resizable().frame(width: 20, height: 20)
                            Text(group.label(for: app)).font(.system(size: 12.5)).foregroundStyle(.white)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                    }
                }
                .frame(width: 240)
            }
            Divider().overlay(Color.white.opacity(0.12))
            HStack {
                Text(group.folderName).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text(L("Open in Finder", "Ouvrir dans le Finder")).font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(14)
        .fixedSize()
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial))
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
        .environment(\.colorScheme, .dark)
        .padding(.bottom, 12)
        .scaleEffect(expanded ? 1 : 0.4, anchor: .bottom)
        .opacity(expanded ? 1 : 0)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.82), value: expanded)
    }

    // MARK: Dock

    private var dock: some View {
        HStack(spacing: 10) {
            // Symmetric on purpose: the group's tile sits on the centre line
            // the fan rises from.
            if group.mode == .folder { ghostTile }
            ghostTile
            if group.mode == .stack { Rectangle().fill(.white.opacity(0.22)).frame(width: 1, height: 38) }
            Button { expanded.toggle() } label: { tile }
                .buttonStyle(.plain)
                .help(expanded ? L("Close", "Refermer") : L("Open", "Déplier"))
                .overlay(alignment: .top) {
                    if !expanded {
                        Text(group.folderName).font(.system(size: 11, weight: .medium)).foregroundStyle(.white)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(Capsule().fill(.black.opacity(0.5)))
                            .fixedSize().offset(y: -30)
                            .transition(.opacity)
                    }
                }
            if group.mode == .folder {
                ghostTile; ghostTile
            } else {
                Image(systemName: "trash").font(.system(size: 24, weight: .light)).foregroundStyle(.white.opacity(0.75))
                    .frame(width: 63, height: 52)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom), lineWidth: 0.75))
        .environment(\.colorScheme, .dark)
    }

    private var ghostTile: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.06)], startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.1)))
            .frame(width: 52, height: 52)
    }

    /// Closed: the apps piled up, the first one in front. Open: the chevron.
    @ViewBuilder private var tile: some View {
        ZStack {
            if expanded && !apps.isEmpty && group.mode == .stack {
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.black.opacity(0.55))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.white.opacity(0.12)))
                    .overlay(Image(systemName: "chevron.down").font(.system(size: 19, weight: .semibold)).foregroundStyle(.white))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                DockTileIcon(group: group, image: image, size: 52).transition(.opacity)
            }
        }
        .frame(width: 52, height: 52)
        .animation(.easeInOut(duration: 0.18), value: expanded)
    }
}

/// The desk the preview stands on: the dark of the logo with its glow.
private struct Backdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.09, green: 0.09, blue: 0.12), Color(red: 0.035, green: 0.035, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Brand.ember.opacity(0.28), .clear], center: UnitPoint(x: 0.85, y: 0.95),
                           startRadius: 10, endRadius: 520)
            RadialGradient(colors: [Color(red: 0.45, green: 0.5, blue: 0.7).opacity(0.14), .clear], center: UnitPoint(x: 0.1, y: 0.0),
                           startRadius: 10, endRadius: 520)
            // A faint grid, like a surface to set the stack on.
            Canvas { context, size in
                let spacing: CGFloat = 28
                var path = Path()
                var x: CGFloat = 0
                while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
                var y: CGFloat = 0
                while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
                context.stroke(path, with: .color(.white.opacity(0.025)), lineWidth: 0.5)
            }
        }
    }
}

/// Where a fan item sits. Closed, every item waits inside the tile; open,
/// each one springs out a beat after the one below it.
private struct FanPlacement: ViewModifier {
    let index: Int
    let step: CGFloat
    let expanded: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let i = CGFloat(index)
        let x = i * i * 0.55
        let y = -(i * step) - 6
        content
            .rotationEffect(.degrees(expanded ? Double(i) * 0.9 : 0), anchor: .trailing)
            .offset(x: expanded ? x : 0, y: expanded ? y : step)
            .scaleEffect(expanded ? 1 : 0.35, anchor: .bottom)
            .opacity(expanded ? 1 : 0)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.12)
                    : .spring(response: 0.34, dampingFraction: 0.78).delay(expanded ? Double(index) * 0.022 : 0),
                value: expanded
            )
    }
}

/// The closed stack: the first apps piled on each other, the first in front.
struct PileIcon: View {
    let apps: [AppEntry]
    let size: CGFloat

    var body: some View {
        ZStack {
            if apps.isEmpty {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(Brand.tertiary, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: size * 0.8, height: size * 0.8)
                    .overlay(Image(systemName: "plus").font(.system(size: size * 0.3, weight: .medium)).foregroundStyle(Brand.tertiary))
            } else {
                ForEach(Array(apps.prefix(3).enumerated().reversed()), id: \.element.id) { index, app in
                    Image(nsImage: app.icon).resizable().interpolation(.high)
                        .scaleEffect(1 - CGFloat(index) * 0.08)
                        .offset(y: CGFloat(-index) * size * 0.07)
                        .opacity(index == 0 ? 1 : 0.85)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

/// The group's tile as the Dock shows it, for any mode and icon style.
struct DockTileIcon: View {
    let group: DockGroup
    let image: NSImage?
    var size: CGFloat = 52

    var body: some View {
        switch group.effectiveTileStyle {
        case .appGrid, .image:
            // Composed icons carry Apple's margin: scale up to match the
            // other tiles' visible size.
            ComposedIcon(group: group, image: image, size: size * 1.18).frame(width: size, height: size)
        case .folder:
            Image(nsImage: NSWorkspace.shared.icon(for: .folder)).resizable().interpolation(.high).frame(width: size * 1.04, height: size * 1.04)
        case .stack:
            if group.apps.isEmpty {
                Image(nsImage: NSWorkspace.shared.icon(for: .folder)).resizable().frame(width: size * 1.04, height: size * 1.04)
            } else {
                PileIcon(apps: group.displayedApps, size: size)
            }
        }
    }
}
