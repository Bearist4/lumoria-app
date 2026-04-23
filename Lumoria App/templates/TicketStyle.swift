//
//  TicketStyle.swift
//  Lumoria App
//
//  A style variant ("colorway") for a ticket template. Each template
//  exposes one or more variants via `TicketStyleCatalog.styles(for:)`.
//
//  Persistence: only the variant's `id` is stored on the ticket
//  (column `style_id`). The struct itself lives in-memory and is
//  resolved at render time via the catalog. NULL `style_id` falls
//  back to the template's default (first variant).
//

import SwiftUI

// MARK: - Variant

/// Visual configuration for one colorway of a ticket template.
///
/// Templates differ in which fields they consume — Studio uses every
/// field, Afterglow currently ships with a single baked-in variant and
/// only the background. New fields can be added here as more templates
/// gain variants.
struct TicketStyleVariant: Identifiable {

    /// Stable identifier persisted on the ticket — `"<template>.<variant>"`,
    /// e.g. `"studio.light"`.
    let id: String

    /// Human-readable label shown under the swatch in the picker.
    let label: String

    /// Asset name for the template's main background / gradient image.
    /// Nil when the template draws its background entirely in code.
    let backgroundAsset: String?

    /// Primary text color used for the ticket's main copy.
    let textPrimary: Color

    /// De-emphasised text — labels, secondary location lines.
    let textSecondary: Color

    /// Brand-style accent used for chevrons, pills, icon tints.
    let accent: Color

    /// Foreground color for content drawn on top of `accent` fills.
    let onAccent: Color

    /// Fine divider line color (Studio uses this between sections).
    let divider: Color

    /// Footer / strip fill (Studio's "Made with Lumoria" bar). Flips
    /// per variant: black in light mode, white in dark mode.
    let footerFill: Color

    /// Foreground color for content on top of `footerFill`.
    let footerText: Color

    /// Color scheme used when rendering brand assets that adapt
    /// (e.g. the "Made with Lumoria" logotype) on top of `footerFill`.
    /// `.dark` for dark fills, `.light` for light fills.
    let footerScheme: ColorScheme

    /// Pre-computed palette shown by `StyleTile` in the picker.
    let swatch: StyleSwatchPalette
}

// MARK: - Catalog

/// Static catalog of style variants per template. Add a new variant by
/// extending the relevant array.
enum TicketStyleCatalog {

    static func styles(for template: TicketTemplateKind) -> [TicketStyleVariant] {
        switch template {
        case .studio:    return studio
        case .afterglow: return afterglow
        case .heritage:  return heritage
        case .terminal:  return terminal
        case .prism:     return prism
        case .express:   return express
        case .orient:    return orient
        case .night:     return night
        case .post:      return post
        case .glow:        return glow
        case .concert:     return concert
        case .underground: return underground
        }
    }

    // MARK: Studio

    private static let studio: [TicketStyleVariant] = [
        // Default ships with the original Studio art (cream + pink
        // gradient, red accent). First entry = fallback for any ticket
        // whose `style_id` is NULL or no longer in the catalog.
        studioLight(
            id: "studio.default",
            label: "Default",
            asset: "studio-bg-default",
            base: Color(hex: "FFFCF0"),
            accent: Color(hex: "D94544"),
            onAccent: .white
        ),
        studioLight(
            id: "studio.butter",
            label: "Butter",
            asset: "studio-bg-butter",
            base: Color(hex: "FBECC3"),
            accent: Color(hex: "4B3A1F"),
            onAccent: .white
        ),
        studioLight(
            id: "studio.sand",
            label: "Sand",
            asset: "studio-bg-sand",
            base: Color(hex: "E9D7BE"),
            accent: Color(hex: "B5432C"),
            onAccent: .white
        ),
        studioLight(
            id: "studio.mist",
            label: "Mist",
            asset: "studio-bg-mist",
            base: Color(hex: "E6EEF3"),
            accent: Color(hex: "3B5B8C"),
            onAccent: .white
        ),
        studioLight(
            id: "studio.bone",
            label: "Bone",
            asset: "studio-bg-bone",
            base: Color(hex: "F1EAE0"),
            accent: Color(hex: "1B2340"),
            onAccent: .white
        ),
        studioDark(
            id: "studio.midnight",
            label: "Midnight",
            asset: "studio-bg-midnight",
            base: Color(hex: "0C1428"),
            accent: Color(hex: "E7B85F"),
            onAccent: .black,
            footerFill: .white,
            footerText: .black,
            footerScheme: .light
        ),
        studioDark(
            id: "studio.forest",
            label: "Forest",
            asset: "studio-bg-forest",
            base: Color(hex: "0A2720"),
            accent: Color(hex: "C7D1C0"),
            onAccent: .black,
            footerFill: .white,
            footerText: .black,
            footerScheme: .light
        ),
    ]

    /// Builder for the Studio *light* variant pattern: black body text
    /// on a tinted pale background, black "Made with" strip with white
    /// label. Two-zone swatch: container = pale ticket bg, tab = accent.
    private static func studioLight(
        id: String,
        label: String,
        asset: String,
        base: Color,
        accent: Color,
        onAccent: Color
    ) -> TicketStyleVariant {
        TicketStyleVariant(
            id: id,
            label: label,
            backgroundAsset: asset,
            textPrimary: .black,
            textSecondary: .black.opacity(0.4),
            accent: accent,
            onAccent: onAccent,
            divider: Color.black.opacity(0.07),
            footerFill: .black,
            footerText: .white,
            footerScheme: .dark,
            swatch: StyleSwatchPalette(
                surface: accent,         // tab = artifact color
                accent: accent,
                background: base,        // container = pale ticket bg
                textOnSurface: onAccent,
                textOnBackground: .black,
                layout: .twoZone
            )
        )
    }

    /// Builder for the Studio *dark* variant pattern: white body text
    /// on a deep tinted background. Footer styling is explicit because
    /// Sage ships with a black strip while Forest ships with a white
    /// one; both are legitimate inverses within the dark family.
    private static func studioDark(
        id: String,
        label: String,
        asset: String,
        base: Color,
        accent: Color,
        onAccent: Color,
        footerFill: Color,
        footerText: Color,
        footerScheme: ColorScheme
    ) -> TicketStyleVariant {
        TicketStyleVariant(
            id: id,
            label: label,
            backgroundAsset: asset,
            textPrimary: .white,
            textSecondary: .white.opacity(0.4),
            accent: accent,
            onAccent: onAccent,
            divider: Color.white.opacity(0.1),
            footerFill: footerFill,
            footerText: footerText,
            footerScheme: footerScheme,
            swatch: StyleSwatchPalette(
                surface: accent,         // tab = artifact color
                accent: accent,
                background: base,        // container = dark ticket bg
                textOnSurface: onAccent,
                textOnBackground: .white,
                layout: .twoZone
            )
        )
    }

    // MARK: Other templates — single default for now.
    //
    // These keep the existing visual; the catalog merely declares the
    // default so `Ticket.styleId` always resolves. Add more entries to
    // any of these arrays to expose colorways in the picker.

    private static let afterglow: [TicketStyleVariant] = [
        defaultVariant(
            id: "afterglow.default",
            backgroundAsset: "afterglow-bg",
            swatchBackground: Color(hex: "F2A6C8")
        ),
    ]

    private static let heritage: [TicketStyleVariant] = [
        defaultVariant(
            id: "heritage.default",
            backgroundAsset: "heritage-bg",
            accent: Color(hex: "1A88C5"),
            swatchBackground: Color(hex: "EAF4FB")
        ),
    ]

    private static let terminal: [TicketStyleVariant] = [
        defaultVariant(
            id: "terminal.default",
            backgroundAsset: "terminal-bg",
            swatchBackground: .black
        ),
    ]

    private static let prism: [TicketStyleVariant] = [
        defaultVariant(
            id: "prism.default",
            backgroundAsset: "prism-bg",
            swatchBackground: Color(hex: "C8B5E8")
        ),
    ]

    private static let night: [TicketStyleVariant] = [
        // Nightjet: deep navy sky + moon-blue accent. The view relies
        // on a full-bleed starfield / silhouette artwork; colors below
        // cover the code-drawn overlays (labels, field cards, pill).
        TicketStyleVariant(
            id: "night.default",
            label: "Default",
            backgroundAsset: "night-bg",
            textPrimary: .white,
            textSecondary: Color(red: 120/255, green: 150/255, blue: 255/255).opacity(0.45),
            accent: Color(hex: "A0BEFF"),     // moonlight
            onAccent: Color(hex: "0B0D1A"),   // deep navy on pill
            divider: Color(red: 100/255, green: 130/255, blue: 255/255).opacity(0.1),
            footerFill: .black,
            footerText: .white,
            footerScheme: .dark,
            swatch: StyleSwatchPalette(
                surface: Color(hex: "A0BEFF"),
                accent: Color(hex: "A0BEFF"),
                background: Color(hex: "0B0D1A"),
                textOnSurface: Color(hex: "0B0D1A"),
                textOnBackground: .white,
                layout: .twoZone
            )
        ),
    ]

    private static let orient: [TicketStyleVariant] = [
        // Vintage Orient-Express: deep navy + gold. The view paints
        // the navy + gold border in code, so no background asset.
        TicketStyleVariant(
            id: "orient.default",
            label: "Default",
            backgroundAsset: "orient-bg",
            textPrimary: Color(hex: "F3ECD9"),       // cream highlight
            textSecondary: Color(hex: "D9C797"),     // gold for labels
            accent: Color(hex: "CBAD5D"),            // brand gold
            onAccent: Color(hex: "D9C797"),          // text on accent fills
            divider: Color(hex: "D8C491").opacity(0.4),
            footerFill: .black,
            footerText: .white,
            footerScheme: .dark,
            swatch: StyleSwatchPalette(
                surface: Color(hex: "CBAD5D"),       // gold tab
                accent: Color(hex: "CBAD5D"),
                background: Color(hex: "0E1731"),    // navy ticket bg
                textOnSurface: Color(hex: "0E1731"), // navy on gold
                textOnBackground: Color(hex: "F3ECD9"), // cream on navy
                layout: .twoZone
            )
        ),
    ]

    private static let post: [TicketStyleVariant] = [
        // Cream paper with a warm off-white fill, charcoal type and a
        // hairline rule (the "divider" field drawn across headers +
        // column separators). Values live here rather than hard-coded
        // on the view so future variants (grey stock, blue dye) can
        // extend the array without touching the template body.
        TicketStyleVariant(
            id: "post.default",
            label: "Default",
            backgroundAsset: "post-bg",
            textPrimary: Color(hex: "1B1B1B"),
            textSecondary: Color(hex: "1B1B1B").opacity(0.5),
            accent: Color(hex: "1B1B1B"),
            onAccent: Color(hex: "F5EEDC"),
            divider: Color.black.opacity(0.1),
            footerFill: .black,
            footerText: .white,
            footerScheme: .dark,
            swatch: StyleSwatchPalette(
                surface: Color(hex: "1B1B1B"),
                accent: Color(hex: "1B1B1B"),
                background: Color(hex: "F5EEDC"),
                textOnSurface: Color(hex: "F5EEDC"),
                textOnBackground: Color(hex: "1B1B1B"),
                layout: .twoZone
            )
        ),
    ]

    private static let glow: [TicketStyleVariant] = [
        // Pitch-black card with a warm bloom; values below drive the
        // overlay text (background itself is code-drawn via
        // `GlowBackground`). `accent` is the magenta seed used by the
        // picker swatch so the tile reads as "warm-on-black".
        TicketStyleVariant(
            id: "glow.default",
            label: "Default",
            backgroundAsset: "glow-bg",
            textPrimary: .white,
            textSecondary: .white.opacity(0.5),
            accent: Color(hex: "D6258C"),
            onAccent: .white,
            divider: Color.white.opacity(0.15),
            footerFill: .black,
            footerText: .white,
            footerScheme: .dark,
            swatch: StyleSwatchPalette(
                surface: Color(hex: "D6258C"),
                accent: Color(hex: "D6258C"),
                background: .black,
                textOnSurface: .white,
                textOnBackground: .white,
                layout: .twoZone
            )
        ),
    ]

    private static let underground: [TicketStyleVariant] = [
        // Dark-card subway / metro stub. The template draws its own
        // colours entirely — the line-colour accent comes from the
        // ticket's payload (`UndergroundTicket.lineColor`), not from
        // this variant — so the variant exists purely to satisfy the
        // catalog contract with a neutral dark theme.
        TicketStyleVariant(
            id: "underground.default",
            label: "Default",
            backgroundAsset: nil,
            textPrimary: .white,
            textSecondary: .white.opacity(0.35),
            accent: Color(hex: "6A4FA0"),
            onAccent: .white,
            divider: Color.white.opacity(0.15),
            footerFill: Color(hex: "15151F"),
            footerText: .white,
            footerScheme: .light,
            swatch: StyleSwatchPalette(
                surface: Color(hex: "15151F"),
                accent: Color(hex: "6A4FA0"),
                background: Color(hex: "15151F"),
                textOnSurface: .white,
                textOnBackground: .white,
                layout: .twoZone
            )
        ),
    ]

    private static let concert: [TicketStyleVariant] = [
        // Dreamy pop-concert stub — baby-pink gradient background asset,
        // deep maroon body copy and a warm rose accent that drives the
        // curved artist arc, the heart decorations and the "ADMIT ONE"
        // pill. Future colourways (Midnight, Glitter, etc.) can just
        // append to this array.
        TicketStyleVariant(
            id: "concert.default",
            label: "Default",
            backgroundAsset: "concert-bg",
            textPrimary: Color(hex: "52002F"),
            textSecondary: Color(hex: "80004D").opacity(0.75),
            accent: Color(hex: "F53BAD"),
            onAccent: Color(hex: "FFF2F7"),
            divider: Color(hex: "52002F").opacity(0.12),
            footerFill: Color(hex: "52002F"),
            footerText: Color(hex: "FFF2F7"),
            footerScheme: .dark,
            swatch: StyleSwatchPalette(
                surface: Color(hex: "F53BAD"),
                accent: Color(hex: "F53BAD"),
                background: Color(hex: "FFD1E8"),
                textOnSurface: Color(hex: "FFF2F7"),
                textOnBackground: Color(hex: "52002F"),
                layout: .twoZone
            )
        ),
    ]

    private static let express: [TicketStyleVariant] = [
        // Shinkansen-style red border on white. The Express view paints
        // the red bands in code, so no background asset is needed.
        TicketStyleVariant(
            id: "express.default",
            label: "Default",
            backgroundAsset: nil,
            textPrimary: .black,
            textSecondary: .black.opacity(0.4),
            accent: Color(hex: "E7001C"),  // JR red
            onAccent: .white,
            divider: Color.black.opacity(0.05),
            footerFill: .black,
            footerText: .white,
            footerScheme: .dark,
            swatch: StyleSwatchPalette(
                surface: Color(hex: "E7001C"),
                accent: Color(hex: "E7001C"),
                background: Color(hex: "FAFAFA"),
                textOnSurface: .white,
                textOnBackground: .black,
                layout: .twoZone
            )
        ),
    ]

    /// Convenience builder for the placeholder default variant of a
    /// template that has not been refactored yet. Values mirror the
    /// hardcoded look of the existing template view.
    private static func defaultVariant(
        id: String,
        backgroundAsset: String,
        accent: Color = .black,
        swatchBackground: Color
    ) -> TicketStyleVariant {
        TicketStyleVariant(
            id: id,
            label: "Default",
            backgroundAsset: backgroundAsset,
            textPrimary: .black,
            textSecondary: .black.opacity(0.4),
            accent: accent,
            onAccent: .white,
            divider: Color.black.opacity(0.07),
            footerFill: .black,
            footerText: .white,
            footerScheme: .dark,
            swatch: StyleSwatchPalette(
                surface: .white,
                accent: accent,
                background: swatchBackground,
                textOnSurface: .black,
                textOnBackground: .black
            )
        )
    }
}

// MARK: - Template kind helpers

extension TicketTemplateKind {

    /// Variants available for this template.
    var styles: [TicketStyleVariant] { TicketStyleCatalog.styles(for: self) }

    /// Default variant (always the first entry — invariant: catalog
    /// arrays are non-empty).
    var defaultStyle: TicketStyleVariant { styles[0] }

    /// Whether the picker step should be shown for this template.
    /// True when there is more than one variant to choose from.
    var hasStyleVariants: Bool { styles.count > 1 }

    /// Resolves a `styleId` (possibly nil, possibly stale) into a
    /// renderable variant. Falls back to the default on miss.
    func resolveStyle(id: String?) -> TicketStyleVariant {
        guard let id, let match = styles.first(where: { $0.id == id }) else {
            return defaultStyle
        }
        return match
    }
}
