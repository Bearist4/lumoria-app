//
//  MadeWithLumoria.swift
//  Lumoria App
//
//  Design: figma.com/design/ncigoEA8cWtAV9032di7KP/Design-System?node-id=15-372
//
//  "Made with Lumoria" watermark. Two visual styles (Black/White), two
//  versions (Full = wordmark, Small = logomark only), and a `scale`
//  parameter so tickets can render it at a fraction of its natural size.
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

    @Environment(\.brandSlug) private var brandSlug

    var style: Style = .black
    var version: Version = .full
    var displayMadeWith: Bool = true
    /// Uniformly scales every size token — fonts, padding, logomark, corner
    /// radius. Default 1.0 = the full-size reference design; ticket templates
    /// pass something like 0.4 to fit inside their tiny rendered bounds.
    var scale: CGFloat = 1.0
    /// When true the component expands to its parent's width and swaps the
    /// rounded pill background for a full-bleed rectangle — used by ticket
    /// templates that want the watermark to span the whole bottom strip
    /// (e.g. the vertical Orient Express).
    var fullWidth: Bool = false
    /// Overrides the default `12 * scale` horizontal inset. Full-width
    /// strips masked by a silhouette usually need a larger inset so the
    /// "Made with" label and the Lumoria wordmark don't land on the
    /// curved/notched edges of the strip. Vertical padding stays at
    /// `12 * scale` in every case.
    var horizontalPadding: CGFloat? = nil

    var body: some View {
        HStack(spacing: 8 * scale) {
            if displayMadeWith {
                Text("Made with")
                    .font(.system(size: 17 * scale, weight: .semibold))
                    .tracking(-0.43 * scale)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            // In full-width mode push the logo to the trailing edge so
            // the strip reads as "Made with … Lumoria" across the full
            // width of the masked area.
            if fullWidth { Spacer(minLength: 0) }

            switch version {
            case .full:
                fullLogo
            case .small:
                logomark(size: 24 * scale)
            }
        }
        .padding(.horizontal, horizontalPadding ?? (12 * scale))
        .padding(.vertical, 12 * scale)
        .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
        .background(backgroundFill)
    }

    @ViewBuilder
    private var backgroundFill: some View {
        if fullWidth {
            Rectangle().fill(backgroundColor)
        } else {
            RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                .fill(backgroundColor)
        }
    }

    // MARK: - Logo composition

    /// `brand/<slug>/full` is the "Lumoria" wordmark (the 7-point star
    /// on the `i` is part of the asset). Height is anchored to 28pt at
    /// `scale == 1` — visibly larger than the 17pt "Made with" label so
    /// the brand name reads as the dominant element at any render size.
    /// `<slug>` follows the current `brandSlug` env value.
    private var fullLogo: some View {
        Image("brand/\(brandSlug)/full")
            .resizable()
            .scaledToFit()
            .frame(height: 28 * scale)
            .environment(\.colorScheme, assetColorScheme)
    }

    private func logomark(size: CGFloat) -> some View {
        Image("brand/\(brandSlug)/logomark")
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

// MARK: - Environment: watermark visibility

/// Global toggle for the "Made with Lumoria" watermark. Templates read this
/// to decide whether to render their watermark badge. `ExportRenderView`
/// sets it to `false` when the user disables the watermark in the export
/// sheet so the rendered image comes out clean.
private struct ShowsLumoriaWatermarkKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var showsLumoriaWatermark: Bool {
        get { self[ShowsLumoriaWatermarkKey.self] }
        set { self[ShowsLumoriaWatermarkKey.self] = newValue }
    }
}

// MARK: - Environment: notch cutout fill

/// When templates have perforated/notched silhouettes (e.g. Prism), they
/// paint a solid base color behind the clipped aurora so the notches read
/// as intentional cutouts against a white wall. Rendering against a
/// contrasting canvas — or when we want the notches to read as true
/// transparent holes (IM share card) — set this to `false` and the base
/// layer is skipped; the notches become transparent.
private struct TicketFillsNotchCutoutsKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var ticketFillsNotchCutouts: Bool {
        get { self[TicketFillsNotchCutoutsKey.self] }
        set { self[TicketFillsNotchCutoutsKey.self] = newValue }
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
        MadeWithLumoria(style: .white, version: .full, scale: 0.4)
    }
    .padding(24)
    .background(Color.Background.elevated)
}
