//
//  StyleTile.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=978-17214
//
//  Pick-one tile used to choose a *style variant* (colorway) for a ticket
//  template. Shows a 120×120 palette swatch — top-left surface, bottom-left
//  accent, right half background, and a diagonal divider — above the label.
//

import SwiftUI

struct StyleTile: View {

    let title: String
    let palette: StyleSwatchPalette
    var isSelected: Bool = false
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            SelectionTile(isSelected: isSelected) {
                VStack(spacing: 12) {
                    StyleSwatch(palette: palette)
                        .frame(width: 120, height: 120)

                    SelectionTileLabel(text: title, isSelected: isSelected)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Palette

/// Colors used to preview a style. Maps roughly to the 4 zones in the swatch.
struct StyleSwatchPalette: Equatable {
    /// Top-left quadrant fill.
    let surface: Color
    /// Bottom-left quadrant fill.
    let accent: Color
    /// Right half fill.
    let background: Color
    /// Color of the "Aa" sample text drawn in the surface quadrant.
    let textOnSurface: Color

    /// Quick constructor using palette families (e.g. "Blue") plus weights.
    static func family(_ family: String) -> StyleSwatchPalette {
        StyleSwatchPalette(
            surface:       Color("Colors/\(family)/200"),
            accent:        Color("Colors/\(family)/400"),
            background:    Color("Colors/\(family)/50"),
            textOnSurface: Color("Colors/Gray/Black")
        )
    }
}

// MARK: - Swatch

/// The 120×120 box: 60×60 surface + 60×60 accent stacked on the left,
/// 60×120 background on the right, separated by a diagonal line.
private struct StyleSwatch: View {

    let palette: StyleSwatchPalette

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Right half (background)
            HStack(spacing: 0) {
                Color.clear
                palette.background
            }

            // Top-left quadrant (surface) with "Aa" sample
            ZStack(alignment: .topLeading) {
                palette.surface
                Text("Aa")
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(-0.45)
                    .foregroundStyle(palette.textOnSurface)
                    .padding(.leading, 15)
                    .padding(.top, 17)
            }
            .frame(width: 60, height: 60)

            // Bottom-left quadrant (accent)
            palette.accent
                .frame(width: 60, height: 60)
                .offset(y: 60)

            // Diagonal divider between left and right halves
            diagonalDivider
        }
        .frame(width: 120, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Background.default)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.Border.default, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Soft diagonal seam across the vertical midline, echoing the Figma
    /// swatch where the left palette meets the right background.
    private var diagonalDivider: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                p.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
            }
            .stroke(Color.Border.default, lineWidth: 1)
        }
    }
}

// MARK: - Preview

#Preview("Style tiles") {
    HStack(spacing: 16) {
        StyleTile(title: "Ocean", palette: .family("Blue"))
        StyleTile(title: "Ocean", palette: .family("Blue"), isSelected: true)
    }
    .padding(24)
    .background(Color.Background.default)
}
