//
//  MadeWithLumoria.swift
//  Lumoria App
//
//  Design: figma.com/design/ncigoEA8cWtAV9032di7KP/Design-System?node-id=15-372
//
//  "Made with Lumoria" watermark. Two styles (Black/White), two
//  versions (Full = 260×40 rectangle strip, Small = 95×24 pill),
//  both carrying the Lumoria app-icon tile. A `scale` parameter lets
//  templates render the component at a fraction of its natural size.
//

import SwiftUI

struct MadeWithLumoria: View {

    enum Style {
        case black
        case white
    }

    enum Version {
        case full   // 260×40 rectangle strip
        case small  // 95×24 pill
    }

    @Environment(\.brandSlug) private var brandSlug

    var style: Style = .black
    var version: Version = .full
    var displayMadeWith: Bool = true
    /// 1.0 = natural Figma size (Full = 260×40, Small = 95×24).
    var scale: CGFloat = 1.0
    /// Expand horizontally to the parent's width — used by templates
    /// whose watermark is a full-bleed bottom strip clipped by a mask.
    var fullWidth: Bool = false
    /// Overrides the default horizontal inset (Full = 20, Small = 12).
    var horizontalPadding: CGFloat? = nil

    var body: some View {
        HStack(spacing: version == .small ? 8 * scale : 0) {
            if displayMadeWith {
                Text("Made with")
                    .font(.system(size: textSize, weight: .semibold))
                    .tracking(-0.43 * scale)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(
                        width: version == .full ? 60 * scale : nil,
                        alignment: .center
                    )
            }

            if version == .full || fullWidth {
                Spacer(minLength: 0)
            }

            appIcon(size: iconSize)
                .frame(width: version == .full ? 60 * scale : nil)
        }
        .padding(.horizontal, horizontalPadding ?? horizontalInset)
        .frame(height: height)
        .frame(
            maxWidth: fullWidth ? .infinity : nil,
            alignment: .leading
        )
        .frame(width: fullWidth ? nil : intrinsicWidth)
        .background(backgroundFill)
        // Tickets are locked to light mode even when the system runs
        // dark, so the watermark must not flip its palette either.
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private var backgroundFill: some View {
        switch version {
        case .full:
            Rectangle().fill(backgroundColor)
        case .small:
            Capsule().fill(backgroundColor)
        }
    }

    private func appIcon(size: CGFloat) -> some View {
        Image("brand/\(brandSlug)/logomark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(
                    cornerRadius: size * (6.0 / 20.0), style: .continuous
                )
                .fill(Color(hex: "FFFCF0"))
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: size * (6.0 / 20.0), style: .continuous
                )
            )
    }

    // MARK: - Dimension tokens

    private var height: CGFloat { (version == .full ? 40 : 24) * scale }
    private var horizontalInset: CGFloat { (version == .full ? 16 : 12) * scale }
    private var textSize: CGFloat { (version == .full ? 11 : 10) * scale }
    private var iconSize: CGFloat { (version == .full ? 20 : 15) * scale }
    /// Natural widths at scale 1 match the Figma component set.
    private var intrinsicWidth: CGFloat? { version == .full ? 260 * scale : nil }

    // MARK: - Color tokens

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
