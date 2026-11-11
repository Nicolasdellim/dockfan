//
//  StackPreview.swift
//  Groupdock
//
//  A picture of what the Dock will show. The real stack is macOS's own; this
//  only helps choose apps, order and presentation before applying.
//

import SwiftUI

struct StackPreview: View {
    let group: DockGroup
    @Binding var expanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let iconSize: CGFloat = 46
    private let step: CGFloat = 54

    private var apps: [AppEntry] { group.displayedApps }
    private var fanCount: Int { min(apps.count, 9) }
    private var presentation: StackPresentation {
        group.presentation == .automatic ? (apps.count > 9 ? .grid : .fan) : group.presentation
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                backdrop
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    openContent.frame(maxWidth: .infinity)
                    dock.padding(.bottom, 22)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Pieces

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.36, green: 0.27, blue: 0.86), Color(red: 0.10, green: 0.22, blue: 0.78),
                                    Color(red: 0.05, green: 0.10, blue: 0.45)],
                           startPoint: .top, endPoint: .bottom)
            Ellipse().fill(Color.white.opacity(0.10)).blur(radius: 60).frame(width: 520, height: 260).offset(x: 160, y: 120)
            Ellipse().fill(Color(red: 0.55, green: 0.45, blue: 1).opacity(0.25)).blur(radius: 70).frame(width: 420, height: 200).offset(x: -180, y: -220)
        }
    }

    @ViewBuilder private var openContent: some View {
        switch presentation {
        case .grid, .list: panel
        default: fan
        }
    }

    /// The fan rises from the tile, bending a little to the right and
    /// tilting as it goes, with the name of each app in a pill on its left.
    private var fan: some View {
        let items = Array(apps.prefix(fanCount).enumerated())
        return ZStack(alignment: .bottom) {
            ForEach(items, id: \.element.id) { index, app in
                fanRow(label: group.label(for: app)) {
                    Image(nsImage: app.icon).resizable().interpolation(.high).frame(width: iconSize, height: iconSize)
                }
                .modifier(FanPlacement(index: index, step: step, expanded: expanded, reduceMotion: reduceMotion))
            }
            fanRow(label: "Ouvrir dans le Finder") {
                Circle().fill(.black.opacity(0.35))
                    .overlay(Image(systemName: "arrowshape.turn.up.right.fill").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white))
                    .frame(width: 34, height: 34).frame(width: iconSize, height: iconSize)
            }
            .modifier(FanPlacement(index: fanCount, step: step, expanded: expanded, reduceMotion: reduceMotion))
        }
        .frame(height: CGFloat(fanCount + 1) * step + 10, alignment: .bottom)
        .padding(.bottom, 4)
    }

    private func fanRow<Icon: View>(label: String, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.32)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                .frame(width: 210, alignment: .trailing)
            icon()
        }
        // The icon column sits on the tile's centre line.
        .offset(x: -(210 + 8) / 2)
    }

    /// Grid and list both open as a rounded panel above the tile.
    private var panel: some View {
        let shown = Array(apps.prefix(presentation == .grid ? 15 : 8))
        return VStack(spacing: 10) {
            if presentation == .grid {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(74), spacing: 6), count: min(5, max(1, shown.count))), spacing: 10) {
                    ForEach(shown) { app in
                        VStack(spacing: 4) {
                            Image(nsImage: app.icon).resizable().frame(width: 44, height: 44)
                            Text(group.label(for: app)).font(.system(size: 10)).foregroundStyle(.white).lineLimit(1)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(shown) { app in
                        HStack(spacing: 8) {
                            Image(nsImage: app.icon).resizable().frame(width: 20, height: 20)
                            Text(group.label(for: app)).font(.system(size: 12)).foregroundStyle(.white)
                            Spacer(minLength: 0)
                        }.padding(.horizontal, 8).padding(.vertical, 3)
                    }
                }.frame(width: 230)
            }
            HStack {
                Text(group.folderName).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text("Ouvrir dans le Finder").font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.black.opacity(0.38)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
        .padding(.bottom, 10)
        .scaleEffect(expanded ? 1 : 0.4, anchor: .bottom)
        .opacity(expanded ? 1 : 0)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.82), value: expanded)
    }

    private var dock: some View {
        HStack(spacing: 10) {
            // Symmetric on purpose: the group's tile sits on the centre line
            // the fan rises from.
            ghostTile(Color(red: 0.95, green: 0.62, blue: 0.25))
            Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
            Button { expanded.toggle() } label: { tile }
                .buttonStyle(.plain)
                .help(expanded ? "Refermer" : "Déplier")
                .overlay(alignment: .top) {
                    if !expanded {
                        Text(group.folderName).font(.system(size: 11, weight: .medium)).foregroundStyle(.white)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(Capsule().fill(.black.opacity(0.4))).fixedSize().offset(y: -30)
                    }
                }
            Image(systemName: "trash").font(.system(size: 26, weight: .light)).foregroundStyle(.white.opacity(0.8)).frame(width: 63, height: 52)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
    }

    private func ghostTile(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.55)).frame(width: 52, height: 52)
    }

    /// Closed: the apps piled up, the first one in front. Open: the chevron.
    @ViewBuilder private var tile: some View {
        ZStack {
            if expanded {
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.black.opacity(0.55))
                    .overlay(Image(systemName: "chevron.down").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else if group.tileStyle == .folder || apps.isEmpty {
                Image(nsImage: NSWorkspace.shared.icon(for: .folder)).resizable().frame(width: 54, height: 54)
                    .transition(.opacity)
            } else {
                ForEach(Array(apps.prefix(3).enumerated().reversed()), id: \.element.id) { index, app in
                    Image(nsImage: app.icon).resizable().frame(width: 50, height: 50)
                        .offset(y: CGFloat(-index) * 3).scaleEffect(1 - CGFloat(index) * 0.06)
                        .opacity(index == 0 ? 1 : 0.85)
                }
                .transition(.opacity)
            }
        }
        .frame(width: 52, height: 52)
        .animation(.easeInOut(duration: 0.18), value: expanded)
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
