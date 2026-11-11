//
//  ComposedIcon.swift
//  Docked
//
//  The icon Docked draws for a group: its apps in a small grid on a
//  background, or a picture of the user's. Drawn on Apple's icon grid (a
//  824-point body centred on a 1024 canvas) so it lines up with the icons
//  beside it in the Dock.
//

import AppKit
import SwiftUI

struct ComposedIcon: View {
    let style: TileStyle
    let finish: Finish
    let grid: Int
    let apps: [AppEntry]
    let image: NSImage?
    /// The canvas side; the body is 80 % of it, as on Apple's grid.
    var size: CGFloat = 128

    private var body_: CGFloat { size * 824 / 1024 }
    private var radius: CGFloat { body_ * 0.225 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.black.opacity(0.28))
                .frame(width: body_, height: body_)
                .blur(radius: size * 0.018)
                .offset(y: size * 0.012)
            content
                .frame(width: body_, height: body_)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.08), .white.opacity(0.25)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing),
                                      lineWidth: max(0.5, size * 0.006))
                )
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder private var content: some View {
        if style == .image, let image {
            Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
                .frame(width: body_, height: body_)
        } else {
            ZStack {
                background
                appGrid
            }
        }
    }

    private var background: some View {
        let (top, bottom) = finish.colors
        return ZStack {
            LinearGradient(colors: [Color(nsColor: top), Color(nsColor: bottom)], startPoint: .top, endPoint: .bottom)
            // The light a glass tile catches on its upper half.
            LinearGradient(colors: [.white.opacity(finish == .glass ? 0.45 : 0.22), .clear], startPoint: .top, endPoint: .center)
            RadialGradient(colors: [.white.opacity(0.18), .clear], center: .topLeading, startRadius: 0, endRadius: body_ * 0.9)
        }
    }

    private var appGrid: some View {
        let n = max(2, min(3, grid))
        let shown = Array(apps.prefix(n * n))
        let inset = body_ * (n == 2 ? 0.15 : 0.12)
        let gap = body_ * (n == 2 ? 0.06 : 0.04)
        let cell = (body_ - inset * 2 - gap * CGFloat(n - 1)) / CGFloat(n)
        return VStack(spacing: gap) {
            ForEach(0..<n, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<n, id: \.self) { column in
                        let index = row * n + column
                        if index < shown.count {
                            Image(nsImage: shown[index].icon).resizable().interpolation(.high)
                                .frame(width: cell * 1.12, height: cell * 1.12)   // app icons carry their own margin
                                .frame(width: cell, height: cell)
                                .shadow(color: .black.opacity(0.18), radius: cell * 0.04, y: cell * 0.03)
                        } else {
                            RoundedRectangle(cornerRadius: cell * 0.24, style: .continuous)
                                .fill(.white.opacity(finish.isLight ? 0.35 : 0.12))
                                .frame(width: cell * 0.86, height: cell * 0.86)
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
        }
    }
}

extension ComposedIcon {
    init(group: DockGroup, image: NSImage?, size: CGFloat = 128) {
        self.init(style: group.effectiveTileStyle, finish: group.iconFinish, grid: group.iconGrid,
                  apps: group.displayedApps, image: image, size: size)
    }

    /// The icon at 1024 points, as PNG data, for the folder or launcher.
    @MainActor
    static func pngData(for group: DockGroup, image: NSImage?) -> Data? {
        let renderer = ImageRenderer(content: ComposedIcon(group: group, image: image, size: 1024))
        renderer.scale = 1
        guard let cgImage = renderer.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    }
}
