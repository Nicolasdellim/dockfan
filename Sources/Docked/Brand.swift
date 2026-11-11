//
//  Brand.swift
//  Docked
//
//  The look of Docked, taken from its logo: dark smoked glass, white light
//  on the edges, and one warm orange glow.
//

import SwiftUI

enum Brand {
    static let ink = Color(red: 0.043, green: 0.047, blue: 0.063)        // window
    static let surface = Color(red: 0.075, green: 0.078, blue: 0.098)    // panels
    static let raised = Color.white.opacity(0.055)                       // cards on a panel
    static let hairline = Color.white.opacity(0.09)
    static let highlight = Color.white.opacity(0.16)
    static let text = Color.white.opacity(0.94)
    static let secondary = Color.white.opacity(0.58)
    static let tertiary = Color.white.opacity(0.36)

    static let ember = Color(red: 1.0, green: 0.55, blue: 0.29)          // the glow
    static let emberDeep = Color(red: 0.89, green: 0.36, blue: 0.20)
    static let emberGradient = LinearGradient(colors: [Color(red: 1.0, green: 0.63, blue: 0.38), emberDeep],
                                              startPoint: .topLeading, endPoint: .bottomTrailing)
    static let success = Color(red: 0.36, green: 0.84, blue: 0.55)

    static let radius: CGFloat = 16
    static let smallRadius: CGFloat = 10
}

// MARK: - Logo

/// The Docked mark: three glass tiles stacked like a Dock stack, the front
/// one carrying the four-square app grid, lit orange from behind.
struct DockedMark: View {
    var size: CGFloat = 64
    /// Draw the outer rounded tile behind the stack, as on the app icon.
    var withTile = true

    var body: some View {
        let s = size
        ZStack {
            if withTile {
                RoundedRectangle(cornerRadius: s * 0.235, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: 0.17), Color(red: 0.06, green: 0.065, blue: 0.08)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: s * 0.235, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.08), Brand.ember.opacity(0.9)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing),
                                          lineWidth: max(0.5, s * 0.008))
                    )
                    .shadow(color: Brand.ember.opacity(0.35), radius: s * 0.08, x: s * 0.04, y: s * 0.05)
            }
            Group {
                card(s).offset(x: s * 0.15, y: -s * 0.12).opacity(0.7)
                card(s).offset(x: s * 0.06, y: -s * 0.045).opacity(0.85)
                card(s, front: true).offset(x: -s * 0.05, y: s * 0.04)
            }
            .scaleEffect(withTile ? 1 : 1.25)
        }
        .frame(width: s, height: s)
        .accessibilityHidden(true)
    }

    private func card(_ s: CGFloat, front: Bool = false) -> some View {
        let side = s * 0.36
        return RoundedRectangle(cornerRadius: side * 0.26, style: .continuous)
            .fill(LinearGradient(colors: [Color(white: front ? 0.42 : 0.30), Color(red: 0.20, green: 0.17, blue: 0.17)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.26, style: .continuous)
                    .fill(LinearGradient(colors: [.clear, Brand.ember.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.26, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05), Brand.ember.opacity(0.8)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                                  lineWidth: max(0.5, s * 0.006))
            )
            .overlay {
                if front { grid(side) }
            }
            .frame(width: side, height: side)
            .rotationEffect(.degrees(4))
            .shadow(color: .black.opacity(0.35), radius: s * 0.02, x: 0, y: s * 0.015)
    }

    private func grid(_ side: CGFloat) -> some View {
        let cell = side * 0.2, gap = side * 0.06
        return VStack(spacing: gap) {
            HStack(spacing: gap) { dot(cell); dot(cell) }
            HStack(spacing: gap) { dot(cell); dot(cell) }
        }
    }

    private func dot(_ cell: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cell * 0.28, style: .continuous)
            .fill(LinearGradient(colors: [.white, Color(white: 0.85)], startPoint: .top, endPoint: .bottom))
            .frame(width: cell, height: cell)
            .shadow(color: .white.opacity(0.35), radius: cell * 0.2)
    }
}

// MARK: - Surfaces

/// A panel of the window: smoked glass with a light top edge.
struct GlassPanel: ViewModifier {
    var radius: CGFloat = Brand.radius
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Brand.surface.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Brand.highlight, Brand.hairline, Brand.hairline],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1)
            )
    }
}

/// A card inside a panel.
struct GlassCard: ViewModifier {
    var radius: CGFloat = Brand.smallRadius
    var selected = false
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(selected ? Brand.ember.opacity(0.12) : Brand.raised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(selected ? Brand.ember.opacity(0.55) : Brand.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func glassPanel(radius: CGFloat = Brand.radius) -> some View { modifier(GlassPanel(radius: radius)) }
    func glassCard(radius: CGFloat = Brand.smallRadius, selected: Bool = false) -> some View {
        modifier(GlassCard(radius: radius, selected: selected))
    }
}

// MARK: - Buttons

/// The one action that moves a group forward: the orange of the logo.
struct EmberButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(enabled ? 1 : 0.45))
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(enabled ? AnyShapeStyle(Brand.emberGradient) : AnyShapeStyle(Color.white.opacity(0.08)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.white.opacity(enabled ? 0.28 : 0.08), lineWidth: 1)
            )
            .shadow(color: Brand.ember.opacity(enabled ? (configuration.isPressed ? 0.2 : 0.4) : 0), radius: 12, y: 4)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A quiet glass button for everything else.
struct QuietButtonStyle: ButtonStyle {
    var compact = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 11.5 : 12.5, weight: .medium))
            .foregroundStyle(enabled ? Brand.text : Brand.tertiary)
            .padding(.horizontal, compact ? 9 : 12)
            .frame(height: compact ? 26 : 32)
            .background(
                RoundedRectangle(cornerRadius: compact ? 8 : 9, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.075))
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 8 : 9, style: .continuous)
                    .strokeBorder(Brand.hairline, lineWidth: 1)
            )
    }
}

/// A round icon button, for the toolbar of a panel.
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 28
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Brand.text)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.white.opacity(configuration.isPressed ? 0.16 : 0.08)))
            .overlay(Circle().strokeBorder(Brand.hairline, lineWidth: 1))
            .contentShape(Circle())
    }
}

/// A small section title, in capitals like a label on a device.
struct SectionLabel: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Brand.tertiary)
    }
}
