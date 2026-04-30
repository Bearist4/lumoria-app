//
//  LineHandle.swift
//  Lumoria App
//
//  Pill marker for one operator line. Coloured background from
//  `TransitLine.color`, white mode glyph on the leading edge and
//  the line short-name in heavy rounded type. Used in the route
//  dropdown's collapsed / expanded states and anywhere a chain of
//  lines needs to be shown compactly.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1876-49431
//

import SwiftUI

struct LineHandle: View {
    let line: TransitLine
    var size: Size = .medium

    enum Size {
        /// Used in the collapsed dropdown field and route-row chain.
        case medium
        /// Slightly tighter variant for dense layouts.
        case small
    }

    var body: some View {
        let rgb = Self.rgb(forHex: line.color)
        let luminance = Self.relativeLuminance(rgb)
        // White text fails on yellow / pastel brand colours (Wiener Linien
        // U6, Tokyo Ginza, Nantes' yellow bus 4) and black text fails on
        // dark blues / reds — pick whichever foreground gives the better
        // WCAG contrast against this specific brand colour.
        let foreground: Color = luminance > 0.55 ? .black : .white
        // When the brand colour is near-white (Nantes' "NC" #FFFFFF), the
        // pill itself disappears against the dropdown's light card. Add a
        // hairline outline so the shape stays visible without changing
        // the operator's brand fill.
        let needsOutline = luminance > 0.9

        return HStack(spacing: iconTextGap) {
            Image(systemName: line.resolvedMode.symbol)
                .font(iconFont)
                .foregroundStyle(foreground)
            Text(line.displayLabel)
                .font(labelFont)
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            Capsule().fill(Color(hex: line.color))
        )
        .overlay {
            if needsOutline {
                Capsule().stroke(Color.Border.hairline, lineWidth: 1)
            }
        }
    }

    // MARK: - Contrast

    /// Parses an `#RRGGBB` or `#RRGGBBAA` hex into an `(r, g, b)` triple
    /// in 0…1 sRGB space. Returns mid-grey for malformed input so the
    /// downstream luminance check still produces a sensible foreground.
    private static func rgb(forHex hex: String) -> (r: Double, g: Double, b: Double) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        switch cleaned.count {
        case 6:
            return (
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255
            )
        case 8:
            return (
                Double((int >> 24) & 0xFF) / 255,
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255
            )
        default:
            return (0.5, 0.5, 0.5)
        }
    }

    /// WCAG 2.1 relative luminance: weights linear-sRGB channels by
    /// human eye sensitivity. The threshold for switching foreground
    /// colour is empirical, not formulaic — 0.55 lands closer to where
    /// brand pastels (yellow, mint) start failing white text in real
    /// renders than the textbook 0.5.
    private static func relativeLuminance(
        _ rgb: (r: Double, g: Double, b: Double)
    ) -> Double {
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.r)
             + 0.7152 * linear(rgb.g)
             + 0.0722 * linear(rgb.b)
    }

    // MARK: - Metrics

    private var iconFont: Font {
        switch size {
        case .small:  return .system(size: 9,  weight: .semibold)
        case .medium: return .system(size: 11, weight: .semibold)
        }
    }

    private var labelFont: Font {
        switch size {
        case .small:  return .system(size: 10, weight: .heavy, design: .rounded)
        case .medium: return .system(size: 12, weight: .heavy, design: .rounded)
        }
    }

    private var iconTextGap: CGFloat { size == .small ? 3 : 4 }
    private var horizontalPadding: CGFloat { size == .small ? 8 : 10 }
    private var verticalPadding: CGFloat { size == .small ? 3 : 4 }
}
