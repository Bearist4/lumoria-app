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
    var id: String

    /// Human-readable label shown under the swatch in the picker.
    var label: String

    /// Asset name for the template's main background / gradient image.
    /// Nil when the template draws its background entirely in code or
    /// the variant uses a flat `backgroundColor` override instead.
    var backgroundAsset: String?

    /// Flat-fill background. When non-nil, templates render this color
    /// behind the ticket body instead of `backgroundAsset`. Defaults
    /// to nil so existing variants keep using their image asset.
    var backgroundColor: Color? = nil

    /// Primary text color used for the ticket's main copy.
    var textPrimary: Color

    /// De-emphasised text — labels, secondary location lines.
    var textSecondary: Color

    /// Brand-style accent used for chevrons, pills, icon tints.
    var accent: Color

    /// Foreground color for content drawn on top of `accent` fills.
    var onAccent: Color

    /// Fine divider line color (Studio uses this between sections).
    var divider: Color

    /// Footer / strip fill (Studio's "Made with Lumoria" bar). Flips
    /// per variant: black in light mode, white in dark mode.
    var footerFill: Color

    /// Foreground color for content on top of `footerFill`.
    var footerText: Color

    /// Color scheme used when rendering brand assets that adapt
    /// (e.g. the "Made with Lumoria" logotype) on top of `footerFill`.
    /// `.dark` for dark fills, `.light` for light fills.
    var footerScheme: ColorScheme

    /// Pre-computed palette shown by `StyleTile` in the picker.
    var swatch: StyleSwatchPalette

    /// Decorative tint slots — used by templates whose look hinges on
    /// stacked coloured shapes (Prism's three aurora blobs, Terminal's
    /// five-blob field). Optional so existing variants don't have to
    /// declare them; templates that draw multiple tint regions read
    /// these fields directly.
    var tint1: Color? = nil
    var tint2: Color? = nil
    var tint3: Color? = nil
    var tint4: Color? = nil
    var tint5: Color? = nil
}

// MARK: - Per-element overrides

extension TicketStyleVariant {

    /// The discrete recolorable regions a template can expose to the
    /// user. Stored as the dictionary keys in `Ticket.colorOverrides`,
    /// so the raw value MUST stay stable — renaming a case requires a
    /// migration to rewrite saved tickets.
    enum Element: String, CaseIterable {
        case accent
        case onAccent
        case background
        case textPrimary
        /// Decorative tint slots. Prism wires three to its aurora
        /// blobs; Terminal uses all five for its denser blob field;
        /// future templates can use one or more for whatever
        /// stacked-shape regions they expose. The label shown in the
        /// picker is per-template (`StyleStep.title(for:)`) so the
        /// stable enum name stays generic.
        case tint1
        case tint2
        case tint3
        case tint4
        case tint5
    }

    /// Returns a new variant with any matching `colorOverrides` applied
    /// on top of this variant's defaults. Studio-only V1: every
    /// override key is rendered by `StudioTicketView`. Other templates
    /// silently ignore unknown overrides because they read the same
    /// fields.
    func applying(overrides: [String: String]?) -> TicketStyleVariant {
        guard let overrides, !overrides.isEmpty else { return self }
        var copy = self

        if let hex = overrides[Element.accent.rawValue] {
            copy = copy.replacing(\.accent, with: Color(hex: hex))
        }
        if let hex = overrides[Element.onAccent.rawValue] {
            copy = copy.replacing(\.onAccent, with: Color(hex: hex))
        }
        if let hex = overrides[Element.textPrimary.rawValue] {
            copy = copy.replacing(\.textPrimary, with: Color(hex: hex))
        }
        if let hex = overrides[Element.background.rawValue] {
            // Setting a flat background keeps the variant's asset
            // around — the renderer uses it as an alpha mask so the
            // user's color picks up the ticket's cut-corner silhouette
            // (notches, rounded edges, footer strip cutout). When the
            // variant has no asset to begin with, the renderer falls
            // through to a plain rounded fill.
            copy.backgroundColor = Color(hex: hex)
        }

        if let hex = overrides[Element.tint1.rawValue] {
            copy.tint1 = Color(hex: hex)
        }
        if let hex = overrides[Element.tint2.rawValue] {
            copy.tint2 = Color(hex: hex)
        }
        if let hex = overrides[Element.tint3.rawValue] {
            copy.tint3 = Color(hex: hex)
        }
        if let hex = overrides[Element.tint4.rawValue] {
            copy.tint4 = Color(hex: hex)
        }
        if let hex = overrides[Element.tint5.rawValue] {
            copy.tint5 = Color(hex: hex)
        }

        return copy
    }

    /// Tiny helper that returns a new variant with one writable
    /// keypath swapped. Lets us layer overrides without rewriting all
    /// the fields each time.
    private func replacing<T>(_ keyPath: WritableKeyPath<TicketStyleVariant, T>, with value: T) -> TicketStyleVariant {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
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
        case .eurovision:  return eurovision
        case .underground: return underground
        case .sign:        return sign
        case .infoscreen:  return infoscreen
        case .grid:        return grid
        case .lumiere:     return lumiere
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
        label: LocalizedStringResource,
        asset: String,
        base: Color,
        accent: Color,
        onAccent: Color
    ) -> TicketStyleVariant {
        TicketStyleVariant(
            id: id,
            label: String(localized: label.withTicketLocale),
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
        label: LocalizedStringResource,
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
            label: String(localized: label.withTicketLocale),
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
        // Five colourways for the gradient ticket. Each variant ships
        // a distinct (start, end) pair driving the linear gradient
        // (top-left → bottom-right). Hex literals only — NOT palette
        // tokens — so the look is identical in light AND dark mode.
        afterglowVariant(id: "afterglow.default", label: "Default",
                         start: "080055", end: "001B2C"),
        afterglowVariant(id: "afterglow.sunrise", label: "Sunrise",
                         start: "FF8A3D", end: "5C0A3D"),
        afterglowVariant(id: "afterglow.forest", label: "Forest",
                         start: "003C48", end: "1F4C2C"),
        afterglowVariant(id: "afterglow.plum", label: "Plum",
                         start: "5C0A3D", end: "3B0764"),
        afterglowVariant(id: "afterglow.cosmic", label: "Cosmic",
                         start: "1E1B4B", end: "FF007E"),
    ]

    /// Builder for an Afterglow variant — both gradient stops are
    /// passed in as hex strings; everything else (text, divider,
    /// footer) is the same dark-on-deep palette across all five.
    private static func afterglowVariant(
        id: String, label: LocalizedStringResource, start: String, end: String
    ) -> TicketStyleVariant {
        TicketStyleVariant(
            id: id,
            label: String(localized: label.withTicketLocale),
            backgroundAsset: nil,
            backgroundColor: Color(hex: start),
            textPrimary: .white,
            textSecondary: .white.opacity(0.5),
            accent: Color(hex: end),
            onAccent: .white,
            divider: Color.white.opacity(0.1),
            footerFill: .black,
            footerText: .white,
            footerScheme: .dark,
            swatch: StyleSwatchPalette(
                surface: Color(hex: start),
                accent: Color(hex: end),
                background: Color(hex: start),
                textOnSurface: .white,
                textOnBackground: .white,
                layout: .twoZone
            )
        )
    }

    private static let heritage: [TicketStyleVariant] = [
        // Heritage derives every blue from a single accent via the
        // 100/400/500/700 ramp (see `HeritageRamp`). Five colourways
        // pair an accent seed with a complementary paper background.
        heritageVariant(id: "heritage.default",  label: "Default",
                        accent: "1A88C5", paper: "FFFFFF",
                        swatchBg: "EAF4FB"),
        heritageVariant(id: "heritage.forest",   label: "Forest",
                        accent: "2FB69A", paper: "FFFFFF",
                        swatchBg: "DAF5EE"),
        heritageVariant(id: "heritage.sunset",   label: "Sunset",
                        accent: "E38233", paper: "FFFCF0",
                        swatchBg: "FFE4D0"),
        heritageVariant(id: "heritage.crimson",  label: "Crimson",
                        accent: "D94544", paper: "FFF1EF",
                        swatchBg: "FFD9D4"),
        heritageVariant(id: "heritage.lavender", label: "Lavender",
                        accent: "9662CC", paper: "F8F1FF",
                        swatchBg: "E6D2FF"),
    ]

    /// Builder for a Heritage variant. Accent seeds the 100/400/500/
    /// 700 ramp; paper is the bg colour visible through the plane's
    /// perforations.
    private static func heritageVariant(
        id: String, label: LocalizedStringResource,
        accent: String, paper: String, swatchBg: String
    ) -> TicketStyleVariant {
        TicketStyleVariant(
            id: id,
            label: String(localized: label.withTicketLocale),
            backgroundAsset: nil,
            backgroundColor: Color(hex: paper),
            textPrimary: .black,
            textSecondary: .black.opacity(0.4),
            accent: Color(hex: accent),
            onAccent: .white,
            divider: Color.black.opacity(0.1),
            footerFill: .black,
            footerText: .white,
            footerScheme: .dark,
            swatch: StyleSwatchPalette(
                surface: Color(hex: accent),
                accent: Color(hex: accent),
                background: Color(hex: swatchBg),
                textOnSurface: .white,
                textOnBackground: .black,
                layout: .twoZone
            )
        )
    }

    private static let terminal: [TicketStyleVariant] = [
        // Five-blob aurora over a dark paper. Each colourway swaps
        // all 5 blob fills + paper bg for a coherent palette.
        terminalVariant(
            id: "terminal.default", label: "Default",
            paper: "000000",
            tints: ("303E57", "00EAFF", "0025CE", "BADAFF", "4D3589")
        ),
        terminalVariant(
            id: "terminal.sunset", label: "Sunset",
            paper: "1A0F0A",
            tints: ("3D1B0E", "FFD93D", "FF8E53", "FFB55C", "C73E1D")
        ),
        terminalVariant(
            id: "terminal.aurora", label: "Aurora",
            paper: "0A0014",
            tints: ("1B0028", "00B4D8", "2EC4B6", "A8E6CF", "7B2CBF")
        ),
        terminalVariant(
            id: "terminal.magma", label: "Magma",
            paper: "1A0014",
            tints: ("2D0E1B", "FF006E", "C9184A", "FF8FA3", "6A040F")
        ),
        terminalVariant(
            id: "terminal.forest", label: "Forest",
            paper: "081C12",
            tints: ("0B2818", "2D6A4F", "95D5B2", "74C69D", "1B4332")
        ),
    ]

    /// Builder for a Terminal variant. `tints` is a 5-tuple of hex
    /// strings driving the five blob slots in order.
    private static func terminalVariant(
        id: String, label: LocalizedStringResource,
        paper: String,
        tints: (String, String, String, String, String)
    ) -> TicketStyleVariant {
        TicketStyleVariant(
            id: id,
            label: String(localized: label.withTicketLocale),
            backgroundAsset: nil,
            backgroundColor: Color(hex: paper),
            textPrimary: .white,
            textSecondary: .white.opacity(0.4),
            accent: .white,
            onAccent: .black,
            divider: Color.white.opacity(0.07),
            footerFill: Color(hex: paper),
            footerText: .white,
            footerScheme: .dark,
            swatch: StyleSwatchPalette(
                surface: Color(hex: tints.2),
                accent: Color(hex: tints.1),
                background: Color(hex: paper),
                textOnSurface: .white,
                textOnBackground: .white,
                layout: .twoZone
            ),
            tint1: Color(hex: tints.0),
            tint2: Color(hex: tints.1),
            tint3: Color(hex: tints.2),
            tint4: Color(hex: tints.3),
            tint5: Color(hex: tints.4)
        )
    }

    private static let prism: [TicketStyleVariant] = [
        // Five colourways for the three-blob aurora. The canvas keeps
        // its black detail bar + white-text footer across variants;
        // only paper bg + 3 blobs swap.
        prismVariant(
            id: "prism.default", label: "Default",
            paper: "FFFFFF", text: .black,
            tints: ("EA72FF", "FF007E", "FFAA6C")
        ),
        prismVariant(
            id: "prism.sunset", label: "Sunset",
            paper: "FFF5E6", text: .black,
            tints: ("FF6B6B", "FFD93D", "FF8E53")
        ),
        prismVariant(
            id: "prism.ocean", label: "Ocean",
            paper: "F0F8FF", text: .black,
            tints: ("4ECDC4", "1A535C", "00B4D8")
        ),
        prismVariant(
            id: "prism.forest", label: "Forest",
            paper: "F4FAF4", text: .black,
            tints: ("A8E6CF", "7FBC8C", "5BA876")
        ),
        prismVariant(
            id: "prism.cosmic", label: "Cosmic",
            paper: "0A0014", text: .white,
            tints: ("7B2CBF", "FF006E", "5A189A")
        ),
    ]

    /// Builder for a Prism variant. `tints` is a 3-tuple driving the
    /// three blob slots; `text` flips primary copy black/white per
    /// variant (Cosmic uses dark paper, so text needs to invert).
    private static func prismVariant(
        id: String, label: LocalizedStringResource,
        paper: String, text: Color,
        tints: (String, String, String)
    ) -> TicketStyleVariant {
        TicketStyleVariant(
            id: id,
            label: String(localized: label.withTicketLocale),
            backgroundAsset: "prism-bg",
            backgroundColor: Color(hex: paper),
            textPrimary: text,
            textSecondary: .white,
            accent: Color(hex: tints.0),
            onAccent: .white,
            divider: Color.white.opacity(0.07),
            footerFill: Color(hex: "1A1A1A"),
            footerText: .white,
            footerScheme: .dark,
            swatch: StyleSwatchPalette(
                surface: Color(hex: "1A1A1A"),
                accent: Color(hex: tints.0),
                background: Color(hex: paper),
                textOnSurface: .white,
                textOnBackground: text,
                layout: .twoZone
            ),
            tint1: Color(hex: tints.0),
            tint2: Color(hex: tints.1),
            tint3: Color(hex: tints.2)
        )
    }

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

    // Each of the three public-transport templates ships a single
    // variant. The template itself carries the name ("Signal",
    // "Sign", "Infoscreen") so they show up as three separate tiles
    // in the template picker — same pattern as train/post + glow.
    // Every accent colour on the rendered ticket derives from the
    // ticket's `lineColor`, so the swatch values here are purely
    // for the style-picker preview.

    private static let underground: [TicketStyleVariant] = [
        TicketStyleVariant(
            id: "underground.default",
            label: "Default",
            backgroundAsset: nil,
            textPrimary: .white,
            textSecondary: .white.opacity(0.35),
            accent: Color(hex: "E51F33"),
            onAccent: .white,
            divider: Color.white.opacity(0.15),
            footerFill: Color(hex: "0B0C13"),
            footerText: .white,
            footerScheme: .light,
            swatch: StyleSwatchPalette(
                surface: Color(hex: "0B0C13"),
                accent: Color(hex: "E51F33"),
                background: Color(hex: "0B0C13"),
                textOnSurface: .white,
                textOnBackground: .white,
                layout: .twoZone
            )
        ),
    ]

    private static let sign: [TicketStyleVariant] = [
        TicketStyleVariant(
            id: "sign.default",
            label: "Default",
            backgroundAsset: "sign-bg",
            textPrimary: Color(red: 0.12, green: 0.10, blue: 0.08),
            textSecondary: Color(red: 0.45, green: 0.40, blue: 0.32),
            accent: Color(red: 0.16, green: 0.58, blue: 0.38),
            onAccent: .white,
            divider: Color(red: 0.65, green: 0.62, blue: 0.56),
            footerFill: .white,
            footerText: .black,
            footerScheme: .dark,
            swatch: StyleSwatchPalette(
                surface: Color(red: 0.96, green: 0.93, blue: 0.86),
                accent: Color(red: 0.16, green: 0.58, blue: 0.38),
                background: Color(red: 0.99, green: 0.98, blue: 0.93),
                textOnSurface: Color(red: 0.12, green: 0.10, blue: 0.08),
                textOnBackground: Color(red: 0.12, green: 0.10, blue: 0.08),
                layout: .twoZone
            )
        ),
    ]

    private static let infoscreen: [TicketStyleVariant] = [
        TicketStyleVariant(
            id: "infoscreen.default",
            label: "Default",
            backgroundAsset: nil,
            textPrimary: .white,
            textSecondary: Color(red: 0.86, green: 0.86, blue: 0.88).opacity(0.55),
            accent: Color(red: 1, green: 0.72, blue: 0.14),
            onAccent: .black,
            divider: Color.white.opacity(0.1),
            footerFill: Color(red: 0.07, green: 0.07, blue: 0.08),
            footerText: .white,
            footerScheme: .light,
            swatch: StyleSwatchPalette(
                surface: Color(red: 0.04, green: 0.04, blue: 0.05),
                accent: Color(red: 1, green: 0.72, blue: 0.14),
                background: Color(red: 0.07, green: 0.07, blue: 0.08),
                textOnSurface: Color(red: 1, green: 0.72, blue: 0.14),
                textOnBackground: .white,
                layout: .twoZone
            )
        ),
    ]

    private static let grid: [TicketStyleVariant] = [
        // Cream graph-paper base, line-colour band along the bottom.
        // Body copy is black on a near-white card; the line accent is
        // injected per-ticket from `UndergroundTicket.lineColor` so
        // the swatch here just describes the chrome.
        TicketStyleVariant(
            id: "grid.default",
            label: "Default",
            backgroundAsset: "grid-bg",
            textPrimary: .black,
            textSecondary: .black.opacity(0.3),
            accent: Color(hex: "FFD300"),
            onAccent: .black,
            divider: Color.black.opacity(0.08),
            footerFill: .white,
            footerText: .black,
            footerScheme: .light,
            swatch: StyleSwatchPalette(
                surface: Color(red: 0.98, green: 0.96, blue: 0.92),
                accent: Color(hex: "FFD300"),
                background: Color(red: 0.98, green: 0.96, blue: 0.92),
                textOnSurface: .black,
                textOnBackground: .black,
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

    private static let eurovision: [TicketStyleVariant] = [
        // Vienna 2026 grand-finale stub. Per-country backgrounds live
        // in `eurovision-bg-<cc>` slots, so the variant itself only
        // describes the chrome (white text on a deep-blue fallback for
        // the swatch + the missing-asset path). Future variants — e.g.
        // a "semi-final" or "monochrome" colourway — can append here
        // and toggle via the style picker without touching the view.
        TicketStyleVariant(
            id: "eurovision.default",
            label: "Default",
            backgroundAsset: nil,
            textPrimary: .white,
            textSecondary: .white.opacity(0.7),
            accent: Color(hex: "F72BBD"),
            onAccent: .white,
            divider: Color.white.opacity(0.15),
            footerFill: .white,
            footerText: .black,
            footerScheme: .light,
            swatch: StyleSwatchPalette(
                surface: Color(hex: "0305DF"),
                accent: Color(hex: "F72BBD"),
                background: Color(hex: "0C14E1"),
                textOnSurface: .white,
                textOnBackground: .white,
                layout: .twoZone
            )
        ),
    ]

    private static let lumiere: [TicketStyleVariant] = [
        // Black cinema stub — the poster carries the colour, chrome
        // stays out of the way. Default ships with a warm amber accent
        // so the small-caps labels (date / room / row / seat / cinema)
        // read like a vintage marquee.
        lumiereVariant(
            id: "lumiere.default", label: "Default",
            background: "000000", text: "FFFFFF", accent: "E8A020"
        ),
        // Burgundy-and-gold opera-house feel — deep wine bg, cream
        // body copy, brushed-gold accents.
        lumiereVariant(
            id: "lumiere.velvet", label: "Velvet",
            background: "3A0E16", text: "F5E6C8", accent: "D4AF37"
        ),
        // Midnight-blue arthouse — navy paper, pale-yellow body and a
        // cool icy accent for the labels.
        lumiereVariant(
            id: "lumiere.noir", label: "Noir",
            background: "0A1428", text: "F5DEB3", accent: "9CC4E4"
        ),
        // Cream paper ticket — vintage box-office stub. Dark coffee
        // body copy with a vermilion accent for the labels.
        lumiereVariant(
            id: "lumiere.reel", label: "Reel",
            background: "FFF6E5", text: "2A1810", accent: "C73E1D"
        ),
        // Off-white indie / nouvelle-vague — soft warm paper, near-
        // black body, mustard accent for a modern editorial feel.
        lumiereVariant(
            id: "lumiere.matinee", label: "Matinee",
            background: "F1EBE0", text: "1B1B1B", accent: "C28B00"
        ),
    ]

    /// Builder for a Lumiere variant. Background flips swatch + footer
    /// chrome between light and dark via the resolved text colour, so
    /// callers only pass the three knobs the user actually controls.
    private static func lumiereVariant(
        id: String,
        label: LocalizedStringResource,
        background: String,
        text: String,
        accent: String
    ) -> TicketStyleVariant {
        let bg = Color(hex: background)
        let textColor = Color(hex: text)
        let accentColor = Color(hex: accent)
        // Decide light/dark from the text colour the variant ships with
        // — light text means the bg is dark, so the footer flips to a
        // pale chip and vice-versa.
        let isDarkBackground = (text.uppercased() != "1B1B1B"
                                && text.uppercased() != "2A1810")
        return TicketStyleVariant(
            id: id,
            label: String(localized: label.withTicketLocale),
            backgroundAsset: nil,
            backgroundColor: bg,
            textPrimary: textColor,
            textSecondary: textColor.opacity(0.5),
            accent: accentColor,
            onAccent: isDarkBackground ? .black : .white,
            divider: textColor.opacity(0.15),
            footerFill: isDarkBackground ? .black : .white,
            footerText: isDarkBackground ? .white : .black,
            footerScheme: isDarkBackground ? .dark : .light,
            swatch: StyleSwatchPalette(
                surface: accentColor,
                accent: accentColor,
                background: bg,
                textOnSurface: isDarkBackground ? .black : .white,
                textOnBackground: textColor,
                layout: .twoZone
            )
        )
    }

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

    /// Per-element recolor controls this template wires up. Only the
    /// elements in this set show up as collapsibles in the StyleStep.
    /// Templates not listed here fall back to the themes scroll only.
    ///
    /// Studio supports the full grid; Afterglow exposes background +
    /// text recolor (gradient is the look — accent is a hidden second
    /// gradient stop, not a user-facing knob).
    var supportedOverrideElements: Set<TicketStyleVariant.Element> {
        switch self {
        case .studio:
            return [.accent, .onAccent, .background, .textPrimary]
        case .afterglow:
            // `background` + `accent` are repurposed as the two
            // gradient stops (top-left / bottom-right); `textPrimary`
            // drives every text/glyph/separator at 40% opacity inside
            // the view.
            return [.background, .accent, .textPrimary]
        case .prism:
            // Paper bg + main text plus the three aurora-blob tints.
            // The detail-bar (footerFill) + detail-bar text stay
            // hardcoded for now until we settle on a slot for them.
            return [.background, .textPrimary, .tint1, .tint2, .tint3]
        case .heritage:
            // Heritage derives every blue tone from a single user-picked
            // accent via a 100/400/500/700 ramp; `onAccent` colours the
            // cabin-pill text; `textPrimary` drives the rest of the body
            // copy (airport names + city names + stub); `background`
            // is the colour visible through the perforation cutouts.
            return [.accent, .onAccent, .textPrimary, .background]
        case .terminal:
            // Terminal — heritage envelope shape with five aurora blobs
            // on top. Each blob gets its own colour control; the paper
            // and the text both follow `background` + `textPrimary`.
            return [.background, .textPrimary,
                    .tint1, .tint2, .tint3, .tint4, .tint5]
        case .lumiere:
            // Lumiere — black movie stub with amber labels. Three knobs:
            // background (the surface behind the poster), accent (the
            // small-caps detail labels), and primary text (movie title +
            // value cells). Director text is derived from `textPrimary`
            // at 0.5 opacity so the secondary line tracks recolours.
            return [.background, .accent, .textPrimary]
        default:
            return []
        }
    }

    /// Resolves a `styleId` (possibly nil, possibly stale) into a
    /// renderable variant. Falls back to the default on miss.
    func resolveStyle(id: String?) -> TicketStyleVariant {
        guard let id, let match = styles.first(where: { $0.id == id }) else {
            return defaultStyle
        }
        return match
    }
}
