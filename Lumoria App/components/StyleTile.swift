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

/// Colors used to preview a style. Supports two preview layouts:
///
/// - `.fourZone` (default): surface + accent quadrants on the left,
///   background on the right. Use when the variant has a distinct
///   accent color separate from text/background.
/// - `.twoZone`: a single filled container with a centered surface
///   circle. Use for variants that only meaningfully vary on
///   background + text color (e.g. Studio light vs dark).
struct StyleSwatchPalette: Equatable {
    enum Layout: Equatable {
        case fourZone
        case twoZone
    }

    /// Four-zone: top-left quadrant. Two-zone: bottom-anchored
    /// rounded-top surface tab.
    let surface: Color
    /// Four-zone: bottom-left accent quadrant. Two-zone: unused
    /// (kept so variants can share a single palette type).
    let accent: Color
    /// Four-zone: right half. Two-zone: container fill.
    let background: Color
    /// "Aa" sample color drawn on top of `surface` / `accent`.
    let textOnSurface: Color
    /// "Aa" sample color drawn on top of `background`.
    let textOnBackground: Color
    /// Which layout to render in the picker tile.
    let layout: Layout

    init(
        surface: Color,
        accent: Color,
        background: Color,
        textOnSurface: Color,
        textOnBackground: Color,
        layout: Layout = .fourZone
    ) {
        self.surface = surface
        self.accent = accent
        self.background = background
        self.textOnSurface = textOnSurface
        self.textOnBackground = textOnBackground
        self.layout = layout
    }

    /// Quick constructor using palette families (e.g. "Blue") plus weights.
    static func family(_ family: String) -> StyleSwatchPalette {
        StyleSwatchPalette(
            surface:          Color("Colors/\(family)/200"),
            accent:           Color("Colors/\(family)/400"),
            background:       Color("Colors/\(family)/50"),
            textOnSurface:    Color("Colors/Gray/Black"),
            textOnBackground: Color("Colors/Gray/Black")
        )
    }
}

// MARK: - Swatch

/// Swatch container. Delegates to the correct zone layout based on
/// `palette.layout`. Border + clipping are shared.
private struct StyleSwatch: View {

    let palette: StyleSwatchPalette

    var body: some View {
        ZStack {
            switch palette.layout {
            case .fourZone: FourZoneSwatch(palette: palette)
            case .twoZone:  TwoZoneSwatch(palette: palette)
            }
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
}

/// 60×60 surface quadrant + 60×60 accent quadrant stacked on the left,
/// 60×120 background half on the right, separated by a vertical seam.
/// "Aa" appears on the background (top-right zone) and on the accent
/// (bottom-left zone) to preview text contrast on each.
private struct FourZoneSwatch: View {
    let palette: StyleSwatchPalette

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Right half — background
            HStack(spacing: 0) {
                Color.clear
                palette.background
            }

            // Top-left — surface (no sample text)
            palette.surface
                .frame(width: 60, height: 60)

            // Bottom-left — accent + "Aa" sample
            palette.accent
                .frame(width: 60, height: 60)
                .offset(y: 60)

            // Aa on background — positioned inside the right half
            sampleText(color: palette.textOnBackground)
                .offset(x: 76, y: 18)

            // Aa on accent — positioned inside the bottom-left quadrant
            sampleText(color: palette.textOnSurface)
                .offset(x: 15, y: 77)

            seam
        }
    }

    private func sampleText(color: Color) -> some View {
        Text(verbatim: "Aa")
            .font(.title3)
            .foregroundStyle(color)
    }

    private var seam: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                p.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
            }
            .stroke(Color.Border.default, lineWidth: 1)
        }
    }
}

/// Full-bleed background with a 72×60 bottom-anchored tab (rounded top
/// corners) representing the surface. "Aa" samples appear in both
/// zones so the user can preview text contrast on each.
private struct TwoZoneSwatch: View {
    let palette: StyleSwatchPalette

    var body: some View {
        ZStack(alignment: .topLeading) {
            palette.background

            // Aa on background — centered in the top half
            Text(verbatim: "Aa")
                .font(.title3)
                .foregroundStyle(palette.textOnBackground)
                .frame(width: 72, height: 60)
                .offset(x: 23, y: 0)

            // Bottom-anchored surface tab (rounded top corners only)
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                topTrailingRadius: 16,
                style: .continuous
            )
            .fill(palette.surface)
            .frame(width: 72, height: 60)
            .offset(x: 23, y: 59)

            // Aa on surface — centered inside the tab
            Text(verbatim: "Aa")
                .font(.title3)
                .foregroundStyle(palette.textOnSurface)
                .frame(width: 72, height: 60)
                .offset(x: 23, y: 59)
        }
    }
}

// MARK: - Preview

#Preview("Style tiles") {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            StyleTile(title: "Ocean", palette: .family("Blue"))
            StyleTile(title: "Ocean", palette: .family("Blue"), isSelected: true)
        }
        HStack(spacing: 16) {
            StyleTile(
                title: "Light",
                palette: StyleSwatchPalette(
                    surface: .white,
                    accent: .black,
                    background: Color("Colors/Blue/50"),
                    textOnSurface: .black,
                    textOnBackground: .black,
                    layout: .twoZone
                )
            )
            StyleTile(
                title: "Dark",
                palette: StyleSwatchPalette(
                    surface: .black,
                    accent: .white,
                    background: Color("Colors/Blue/50"),
                    textOnSurface: .white,
                    textOnBackground: .black,
                    layout: .twoZone
                ),
                isSelected: true
            )
        }
    }
    .padding(24)
    .background(Color.Background.default)
}
