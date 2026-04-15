//
//  MadeWithLumoria.swift
//  Lumoria App
//
//  Design: figma.com/design/ncigoEA8cWtAV9032di7KP/Design-System?node-id=15-372
//
//  "Made with Lumoria" watermark. Two visual styles (Black/White) and two
//  versions (Full = wordmark, Small = logomark only).
//

import SwiftUI

struct MadeWithLumoria: View {

    enum Style {
        case black
        case white
    }

    enum Version {
        case full   // logomark + wordmark
        case small  // logomark only
    }

    var style: Style = .black
    var version: Version = .full
    var displayMadeWith: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            if displayMadeWith {
                Text("Made with")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.43)
                    .foregroundStyle(textColor)
            }

            switch version {
            case .full:
                fullLogo
            case .small:
                logomark(size: 24)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundColor)
        )
    }

    // MARK: - Logo composition

    private var fullLogo: some View {
        HStack(spacing: 0) {
            logomark(size: 17.102)

            Spacer(minLength: 4)

            Image("brand/default/full")
                .resizable()
                .scaledToFit()
                .frame(width: 72.186, height: 28.43)
                .environment(\.colorScheme, assetColorScheme)
        }
        .frame(width: 89.288)
    }

    private func logomark(size: CGFloat) -> some View {
        Image("brand/default/logomark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(
                    cornerRadius: size * (4.243 / 24), style: .continuous
                )
                .fill(Color(hex: "FFFCF0"))
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: size * (4.243 / 24), style: .continuous
                )
            )
    }

    // MARK: - Tokens

    private var backgroundColor: Color {
        switch style {
        case .black: return Color.Button.Primary.Background.default
        case .white: return Color.Background.default
        }
    }

    private var textColor: Color {
        switch style {
        case .black: return Color.Button.Primary.Label.default
        case .white: return Color.Text.primary
        }
    }

    /// Forces the wordmark to render its dark- or light-mode variant
    /// regardless of the surrounding system appearance, so a Black watermark
    /// always shows a white wordmark and vice versa.
    private var assetColorScheme: ColorScheme {
        switch style {
        case .black: return .dark
        case .white: return .light
        }
    }
}

// MARK: - Preview

#Preview("Watermark variants") {
    VStack(spacing: 12) {
        MadeWithLumoria(style: .black, version: .full)
        MadeWithLumoria(style: .white, version: .full)
        MadeWithLumoria(style: .black, version: .small)
        MadeWithLumoria(style: .white, version: .small)
        MadeWithLumoria(style: .black, version: .small, displayMadeWith: false)
    }
    .padding(24)
    .background(Color.Background.elevated)
}
