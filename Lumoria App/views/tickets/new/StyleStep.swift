//
//  StyleStep.swift
//  Lumoria App
//
//  Step 5 — user picks a colorway and (premium-only) tweaks individual
//  color elements. The preview tile up top renders the live ticket
//  with decorative `ColorTarget` pills pointing at every recolorable
//  region; the body is a stack of `FormStepCollapsibleItem`s for
//  Pre-made themes + each per-element color picker.
//
//  Studio is the only template wired up for per-element overrides in
//  V1 — every other template still gets the themes scroll only.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=982-28862
//

import SwiftUI

struct NewTicketStyleStep: View {

    @ObservedObject var funnel: NewTicketFunnel
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @Environment(EntitlementStore.self) private var entitlement
    @Environment(Paywall.PresentationState.self) private var paywallState

    @State private var expandedItems: Set<String> = []
    /// Per-element color picks are gated to early adopters. Free
    /// users see the promo sheet on first tap; the sheet shares
    /// presentation state across pick attempts so rapid taps don't
    /// stack copies of the modal.
    @State private var showEarlyAdopterPromo: Bool = false

    var body: some View {
        // Whole step scrolls together — the preview tile keeps its
        // fixed 225pt height (so opening a collapsible can't squish
        // it) but it scrolls off-screen along with the collapsibles
        // below it.
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                StylePreviewTile(funnel: funnel)
                    .frame(height: 225)

                collapsibles
                    .padding(.bottom, 16)
            }
        }
        .onChange(of: funnel.selectedStyleId) { _, newValue in
            guard let newValue, let template = funnel.template else { return }
            Analytics.track(.ticketStyleSelected(
                template: template.analyticsTemplate,
                styleId: newValue
            ))
            if onboardingCoordinator.currentStep == .pickStyle {
                Task { await onboardingCoordinator.advance(from: .pickStyle) }
            }
        }
        .sheet(isPresented: $showEarlyAdopterPromo) {
            EarlyAdopterPromoSheet()
                .environment(entitlement)
        }
    }

    @ViewBuilder
    private var collapsibles: some View {
        VStack(spacing: 8) {
            // Themes scroll only makes sense when there are 2+ variants
            // to scroll through. Single-variant templates (Afterglow)
            // skip this and show their per-element controls directly.
            if showsThemesCollapsible {
                FormStepCollapsibleItem(
                    title: String(localized: "Pre-made themes"),
                    isComplete: false,
                    isExpanded: binding(for: "themes"),
                    showsStatusIcon: false
                ) {
                    themesContent
                }
                .onboardingAnchor("funnel.styles")
            }

            if !supportedElements.isEmpty {
                // Visual divider between the free pre-made themes and
                // the per-element color controls — matches the Figma
                // separation. Inset on both sides keeps it short of
                // the collapsible bg edges. Only renders when there's
                // a themes collapsible above to separate from.
                if showsThemesCollapsible {
                    Divider()
                        .padding(.horizontal, 24)
                }

                // Order chosen so visually-related controls sit
                // adjacent: gradient start → gradient end → text →
                // accent text. Afterglow's `.background` + `.accent`
                // pair render right next to each other; Studio's
                // `.accent` + `.onAccent` likewise.
                if supportedElements.contains(.background) {
                    FormStepCollapsibleItem(
                        title: title(for: .background),
                        isComplete: hasOverride(.background),
                        isExpanded: binding(for: "background"),
                        proBadge: true,
                        showsStatusIcon: false
                    ) {
                        colorList(for: .background, presets: presets(for: .background))
                    }
                }

                if supportedElements.contains(.accent) {
                    FormStepCollapsibleItem(
                        title: title(for: .accent),
                        isComplete: hasOverride(.accent),
                        isExpanded: binding(for: "accent"),
                        proBadge: true,
                        showsStatusIcon: false
                    ) {
                        colorList(for: .accent, presets: presets(for: .accent))
                    }
                }

                if supportedElements.contains(.textPrimary) {
                    FormStepCollapsibleItem(
                        title: title(for: .textPrimary),
                        isComplete: hasOverride(.textPrimary),
                        isExpanded: binding(for: "textPrimary"),
                        proBadge: true,
                        showsStatusIcon: false
                    ) {
                        colorList(for: .textPrimary, presets: presets(for: .textPrimary))
                    }
                }

                if supportedElements.contains(.onAccent) {
                    FormStepCollapsibleItem(
                        title: title(for: .onAccent),
                        isComplete: hasOverride(.onAccent),
                        isExpanded: binding(for: "onAccent"),
                        proBadge: true,
                        showsStatusIcon: false
                    ) {
                        colorList(for: .onAccent, presets: presets(for: .onAccent))
                    }
                }

                // Decorative tints — Prism's three aurora blobs, etc.
                // Labels are per-template (`title(for:)`) so each
                // template can describe its own visual roles.
                if supportedElements.contains(.tint1) {
                    FormStepCollapsibleItem(
                        title: title(for: .tint1),
                        isComplete: hasOverride(.tint1),
                        isExpanded: binding(for: "tint1"),
                        proBadge: true,
                        showsStatusIcon: false
                    ) {
                        colorList(for: .tint1, presets: presets(for: .tint1))
                    }
                }

                if supportedElements.contains(.tint2) {
                    FormStepCollapsibleItem(
                        title: title(for: .tint2),
                        isComplete: hasOverride(.tint2),
                        isExpanded: binding(for: "tint2"),
                        proBadge: true,
                        showsStatusIcon: false
                    ) {
                        colorList(for: .tint2, presets: presets(for: .tint2))
                    }
                }

                if supportedElements.contains(.tint3) {
                    FormStepCollapsibleItem(
                        title: title(for: .tint3),
                        isComplete: hasOverride(.tint3),
                        isExpanded: binding(for: "tint3"),
                        proBadge: true,
                        showsStatusIcon: false
                    ) {
                        colorList(for: .tint3, presets: presets(for: .tint3))
                    }
                }

                if supportedElements.contains(.tint4) {
                    FormStepCollapsibleItem(
                        title: title(for: .tint4),
                        isComplete: hasOverride(.tint4),
                        isExpanded: binding(for: "tint4"),
                        proBadge: true,
                        showsStatusIcon: false
                    ) {
                        colorList(for: .tint4, presets: presets(for: .tint4))
                    }
                }

                if supportedElements.contains(.tint5) {
                    FormStepCollapsibleItem(
                        title: title(for: .tint5),
                        isComplete: hasOverride(.tint5),
                        isExpanded: binding(for: "tint5"),
                        proBadge: true,
                        showsStatusIcon: false
                    ) {
                        colorList(for: .tint5, presets: presets(for: .tint5))
                    }
                }
            }
        }
    }

    // MARK: - Themes content

    private var themesContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(funnel.availableStyles) { variant in
                    StyleTile(
                        title: variant.label,
                        palette: variant.swatch,
                        isSelected: isSelected(variant),
                        onTap: { funnel.selectedStyleId = variant.id }
                    )
                    .frame(width: 140)
                }
            }
            // Horizontal slack so the selected tile's outline doesn't
            // get sliced by the ScrollView edge; vertical so its
            // shadow / outline fully renders.
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }

    private func isSelected(_ variant: TicketStyleVariant) -> Bool {
        if let id = funnel.selectedStyleId { return id == variant.id }
        return variant.id == funnel.template?.defaultStyle.id
    }

    // MARK: - Color list (per element)

    private func colorList(
        for element: TicketStyleVariant.Element,
        presets: [String]
    ) -> some View {
        let key = element.rawValue
        let binding = Binding<String?>(
            get: { funnel.colorOverrides[key] },
            set: { newValue in
                if let new = newValue {
                    funnel.colorOverrides[key] = new
                } else {
                    funnel.colorOverrides.removeValue(forKey: key)
                }
            }
        )
        return ColorListField(
            presets: presets,
            selectedHex: binding,
            onPickAttempt: { _ in attemptColorPick() }
        )
    }

    /// Returns true when the pick should go through, false when the
    /// early-adopter promo was shown instead. Pre-made themes stay
    /// open to everyone (handled at the StyleTile picker layer);
    /// per-element color tweaks are early-adopter-only because the
    /// monetisation kill-switch leaves `hasPremium` true for the
    /// whole free tier — a tier-level gate is the right grain here.
    private func attemptColorPick() -> Bool {
        if entitlement.isEarlyAdopter { return true }
        showEarlyAdopterPromo = true
        return false
    }

    private func hasOverride(_ element: TicketStyleVariant.Element) -> Bool {
        funnel.colorOverrides[element.rawValue] != nil
    }

    // MARK: - Per-template enablement

    /// Set of recolor regions the active template wires up. Drives
    /// which collapsibles render below the themes scroll. Empty set
    /// = themes-only step (templates that haven't opted in yet).
    private var supportedElements: Set<TicketStyleVariant.Element> {
        funnel.template?.supportedOverrideElements ?? []
    }

    /// True when the themes scroll has > 1 tile worth showing.
    /// Afterglow ships a single variant + per-element overrides, so
    /// the scroll would render a 1-tile sliver — hide it instead.
    private var showsThemesCollapsible: Bool {
        funnel.availableStyles.count > 1
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedItems.contains(id) },
            set: { isOn in
                if isOn { expandedItems.insert(id) }
                else    { expandedItems.remove(id) }
            }
        )
    }

    // MARK: - Preset palettes
    //
    // Curated 8-color sets per element. Drawn from the Studio variant
    // accents + a few commonly-asked-for neutrals. The trailing native
    // picker tile in `ColorListField` covers the long tail.

    private let accentPresets: [String] = [
        "D94544", "3B5B8C", "1B2340", "B5432C", "4B3A1F",
        "E7B85F", "C7D1C0", "0A2720",
    ]
    private let onAccentPresets: [String] = [
        "FFFFFF", "000000", "F5EFE3", "1B1B1B",
    ]
    private let backgroundPresets: [String] = [
        "FFFCF0", "FBECC3", "E9D7BE", "E6EEF3", "F1EAE0",
        "0C1428", "0A2720", "1B1B1B",
    ]
    private let textPrimaryPresets: [String] = [
        "000000", "FFFFFF", "1B2340", "4B3A1F", "5C5C5C",
    ]

    // MARK: Afterglow-curated presets

    /// Gradient-start picks for Afterglow — deep, saturated nights
    /// that sit on the dark side of the wheel. Pair well with the
    /// `afterglowAccentPresets` below for a luminous-dawn effect.
    private let afterglowBackgroundPresets: [String] = [
        "080055", "1E1B4B", "0C1428", "1B0028",
        "0A2720", "260F08", "1B1B1B", "0A0A0A",
    ]
    /// Gradient-end picks for Afterglow — warmer / cooler counterparts
    /// to the start palette. Choosing one start + one end from the
    /// same column produces a tonal gradient; cross-column produces a
    /// dawn/dusk crossfade.
    private let afterglowAccentPresets: [String] = [
        "001B2C", "3B0764", "5C0A3D", "FF8A3D",
        "1F4C2C", "B5432C", "2D1B0E", "47185A",
    ]
    private let afterglowTextPresets: [String] = [
        "FFFFFF", "F5EFE3", "FBECC3", "FFD1B4",
        "C7D1C0", "000000",
    ]

    // MARK: Per-template label + preset routing

    /// Renames collapsible titles when the active template repurposes
    /// an `Element` slot — e.g. for Afterglow `.background` and
    /// `.accent` are the two gradient stops, not a flat-fill + accent.
    private func title(for element: TicketStyleVariant.Element) -> String {
        if funnel.template == .afterglow {
            switch element {
            case .background:  return String(localized: "Gradient start")
            case .accent:      return String(localized: "Gradient end")
            case .textPrimary: return String(localized: "Text color")
            case .onAccent:    return String(localized: "Accent text color")
            case .tint1, .tint2, .tint3, .tint4, .tint5: return ""
            }
        }
        if funnel.template == .prism {
            switch element {
            case .background:  return String(localized: "Background color")
            case .textPrimary: return String(localized: "Text color")
            case .tint1:       return String(localized: "Glow")
            case .tint2:       return String(localized: "Midtone")
            case .tint3:       return String(localized: "Highlight")
            case .accent:      return String(localized: "Accent")
            case .onAccent:    return String(localized: "Accent text color")
            case .tint4, .tint5: return ""
            }
        }
        if funnel.template == .terminal {
            switch element {
            case .background:  return String(localized: "Background color")
            case .textPrimary: return String(localized: "Text color")
            case .tint1:       return String(localized: "Backdrop")
            case .tint2:       return String(localized: "Glow")
            case .tint3:       return String(localized: "Midtone")
            case .tint4:       return String(localized: "Highlight")
            case .tint5:       return String(localized: "Accent")
            case .accent:      return String(localized: "Accent")
            case .onAccent:    return String(localized: "Accent text color")
            }
        }
        switch element {
        case .accent:      return String(localized: "Accent")
        case .onAccent:    return String(localized: "Accent text color")
        case .background:  return String(localized: "Background color")
        case .textPrimary: return String(localized: "Text color")
        case .tint1:       return String(localized: "Tint 1")
        case .tint2:       return String(localized: "Tint 2")
        case .tint3:       return String(localized: "Tint 3")
        case .tint4:       return String(localized: "Tint 4")
        case .tint5:       return String(localized: "Tint 5")
        }
    }

    /// Returns the curated preset palette for a given element under
    /// the active template. Falls back to the shared Studio-flavoured
    /// presets for templates that haven't curated their own.
    private func presets(for element: TicketStyleVariant.Element) -> [String] {
        if funnel.template == .afterglow {
            switch element {
            case .background:  return afterglowBackgroundPresets
            case .accent:      return afterglowAccentPresets
            case .textPrimary: return afterglowTextPresets
            case .onAccent:    return onAccentPresets
            case .tint1, .tint2, .tint3, .tint4, .tint5: return prismTintPresets
            }
        }
        if funnel.template == .prism {
            switch element {
            case .background:  return prismBackgroundPresets
            case .textPrimary: return prismTextPresets
            case .tint1, .tint2, .tint3, .tint4, .tint5: return prismTintPresets
            case .accent:      return accentPresets
            case .onAccent:    return onAccentPresets
            }
        }
        if funnel.template == .heritage {
            switch element {
            case .accent:      return heritageAccentPresets
            case .onAccent:    return onAccentPresets
            case .textPrimary: return heritageTextPresets
            case .background:  return heritageBackgroundPresets
            default:           return accentPresets
            }
        }
        if funnel.template == .terminal {
            switch element {
            case .background:  return terminalBackgroundPresets
            case .textPrimary: return terminalTextPresets
            case .tint1, .tint2, .tint3, .tint4, .tint5: return terminalTintPresets
            case .accent:      return accentPresets
            case .onAccent:    return onAccentPresets
            }
        }
        switch element {
        case .accent:      return accentPresets
        case .onAccent:    return onAccentPresets
        case .background:  return backgroundPresets
        case .textPrimary: return textPrimaryPresets
        case .tint1, .tint2, .tint3, .tint4, .tint5: return accentPresets
        }
    }
}

// MARK: - Prism preset palettes (file-scope so the per-element router
// above can reach them without growing the type's surface area).

extension NewTicketStyleStep {
    /// Paper backgrounds — bright neutrals for Prism's white-paper
    /// aesthetic + a few warm tints to match the aurora palette.
    fileprivate var prismBackgroundPresets: [String] {
        ["FFFFFF", "FFFCF0", "F5EFE3", "F1EAE0", "E6EEF3",
         "1A1A1A", "0A0A0A", "0C1428"]
    }
    /// Header text — almost-black neutrals, with a couple of bright
    /// options for inverted-paper variants.
    fileprivate var prismTextPresets: [String] {
        ["000000", "1A1A1A", "1B2340", "4B3A1F", "FFFFFF", "F5EFE3"]
    }
    /// Aurora tints — luminous saturated hues that read clean under
    /// heavy gaussian blur. Same palette feeds Glow / Midtone /
    /// Highlight so the user can mix any combination.
    fileprivate var prismTintPresets: [String] {
        ["EA72FF", "FF007E", "FFAA6C", "6EC4E8", "F5D46A",
         "F07AC0", "5B79F8", "B5432C", "00A86B"]
    }

    /// Heritage accent seeds — vivid mid-tones that ramp cleanly
    /// across 100/400/500/700. Avoid very dark or very pale picks
    /// since the ramp interpolates from the base toward white/black.
    fileprivate var heritageAccentPresets: [String] {
        ["1A88C5", "0090A8", "00957C", "62B650", "92BD24",
         "E38233", "D94544", "9662CC", "5C77DF"]
    }
    /// Heritage body text picks — black, near-black, with a couple of
    /// charcoal alternatives.
    fileprivate var heritageTextPresets: [String] {
        ["000000", "1A1A1A", "1B2340", "404040", "525252"]
    }
    /// Heritage backdrop — colour visible through the plane's
    /// perforation cutouts. Bright neutrals that read clean against
    /// the tinted plane.
    fileprivate var heritageBackgroundPresets: [String] {
        ["FFFFFF", "FFFCF0", "F5EFE3", "EAF4FB", "F1EAE0",
         "FFE4E0", "EFE2FF", "DDF9AF"]
    }

    /// Terminal background picks — deep, atmospheric base colours
    /// that pair cleanly with the saturated blob field on top.
    fileprivate var terminalBackgroundPresets: [String] {
        ["000000", "0A0A0A", "1A1A1A", "0C1428", "1B0028",
         "0E1731", "240046", "001B2C"]
    }
    /// Terminal text — white and near-white tones; the body uses
    /// `textPrimary` directly with stepped opacities.
    fileprivate var terminalTextPresets: [String] {
        ["FFFFFF", "F5EFE3", "FBECC3", "EAF4FB"]
    }
    /// Terminal blob picks — the spec palette plus a few harmonious
    /// alternates. Same set powers all five blob slots.
    fileprivate var terminalTintPresets: [String] {
        ["303E57", "00EAFF", "0025CE", "BADAFF", "4D3589",
         "EA72FF", "FF007E", "FFAA6C", "00A86B", "F5D46A"]
    }
}

// MARK: - Preview tile

/// Renders the live ticket inside a rounded card and overlays
/// decorative `ColorTarget` pills that snap their leader lines onto
/// the regions the underlying template tagged via `.styleAnchor(_:)`.
/// Pills are non-interactive in V1 — they only point at what each
/// collapsible below controls.
private struct StylePreviewTile: View {
    @ObservedObject var funnel: NewTicketFunnel

    var body: some View {
        // Elevated card fills the entire 225pt slot the parent
        // reserves; the ticket render is overlaid centered inside at
        // a fixed dominant-axis size (252pt wide horizontal, 189pt
        // tall vertical) per Figma 982-28862. This decouples the card
        // chrome from the ticket's intrinsic size so expanding /
        // collapsing items below never reflow the preview area.
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.Background.elevated)
            .overlay {
                if let payload = funnel.buildPayload() {
                    let ticket = Ticket(
                        orientation: funnel.orientation,
                        payload: payload,
                        styleId: funnel.selectedStyleId,
                        colorOverrides: funnel.colorOverrides.isEmpty ? nil : funnel.colorOverrides
                    )
                    Group {
                        switch funnel.orientation {
                        case .horizontal:
                            TicketPreview(ticket: ticket, isCentered: true)
                                .frame(width: 252)
                        case .vertical:
                            TicketPreview(ticket: ticket, isCentered: true)
                                .frame(height: 189)
                        }
                    }
                }
            }
            .overlayPreferenceValue(StyleAnchorKey.self) { anchors in
                GeometryReader { proxy in
                    let placements = computePlacements(
                        anchors: anchors.elements,
                        safeArea: anchors.safeArea.map { proxy[$0] },
                        proxy: proxy
                    )
                    ForEach(placements, id: \.element) { placement in
                        AnchoredColorTarget(
                            color: color(for: placement.element),
                            label: label(for: placement.element),
                            direction: placement.direction,
                            leaderLength: placement.leaderLength
                        )
                        .position(placement.knob)
                    }
                }
            }
    }

    // MARK: - Placement

    private struct Placement {
        let element: TicketStyleVariant.Element
        let label: String
        let rect: CGRect
        var direction: ColorTarget.Direction
        var knob: CGPoint
        var leaderLength: CGFloat
        /// Pill-only AABB. Used together with `leaderBBox` for the
        /// composite collision check — see `placementsCollide`.
        var bbox: CGRect
        /// Axis-aligned bbox of the leader stroke. Used so two
        /// targets whose leaders cross (e.g. a vertical leader from
        /// the top and a horizontal leader from the left) are flagged
        /// as colliding and the resolver finds a non-crossing layout.
        var leaderBBox: CGRect
    }

    /// Resolves the anchors into a (best-effort) non-overlapping set
    /// of placements. Two passes:
    ///
    ///   1. **Initial pass** — for each element in a stable priority
    ///      order, pick the first direction that fits inside the card
    ///      and doesn't overlap a pill already placed this pass.
    ///   2. **Resolution pass** — scan for any remaining colliding
    ///      pairs (the initial pass can fail when no priority
    ///      direction fits + clears earlier pills, so it falls back
    ///      to a colliding direction). For each pair, try to move
    ///      one or the other to a fresh direction that breaks the
    ///      overlap without introducing a new one. Repeats up to 8
    ///      times to keep terminating.
    private func computePlacements(
        anchors: [TicketStyleVariant.Element: Anchor<CGRect>],
        safeArea: CGRect?,
        proxy: GeometryProxy
    ) -> [Placement] {
        // Ticket bounds for the adaptive-leader push-out heuristic.
        // Falls back to the full card if the template hasn't tagged
        // a `.background` anchor.
        let ticketBounds: CGRect = {
            guard let anchor = anchors[.background] else {
                return CGRect(origin: .zero, size: proxy.size)
            }
            return proxy[anchor]
        }()

        var placed = initialPlacementPass(
            anchors: anchors,
            safeArea: safeArea,
            proxy: proxy,
            ticket: ticketBounds
        )
        resolveCollisions(
            in: &placed,
            safeArea: safeArea,
            proxy: proxy,
            ticket: ticketBounds
        )
        return placed
    }

    private func initialPlacementPass(
        anchors: [TicketStyleVariant.Element: Anchor<CGRect>],
        safeArea: CGRect?,
        proxy: GeometryProxy,
        ticket: CGRect
    ) -> [Placement] {
        var placed: [Placement] = []
        let order: [ColorTarget.Direction] = [.top, .bottom, .left, .right]

        for element in placementOrder where anchors[element] != nil {
            guard let anchor = anchors[element] else { continue }
            let rect = proxy[anchor]
            let labelText = label(for: element)
            // Only the .background anchor's knob needs clamping —
            // every other element's anchor already sits inside a
            // simple rectangular surface.
            let knobConstraint = element == .background ? safeArea : nil

            // Prefer a direction that satisfies the strict rule (fits
            // inside card AND can push pill outside ticket) AND
            // doesn't collide with already-placed pills.
            var picked: Placement?
            for d in order {
                guard fits(direction: d, rect: rect, size: proxy.size, label: labelText, ticket: ticket) else { continue }
                let candidate = makePlacement(
                    element: element, label: labelText, rect: rect,
                    direction: d, proxy: proxy, ticket: ticket,
                    safeArea: knobConstraint
                )
                if !placed.contains(where: { placementsCollide($0, candidate) }) {
                    picked = candidate
                    break
                }
            }

            // Fall back to any direction satisfying the strict rule
            // (accept collision).
            if picked == nil {
                for d in order {
                    guard fits(direction: d, rect: rect, size: proxy.size, label: labelText, ticket: ticket) else { continue }
                    picked = makePlacement(
                        element: element, label: labelText, rect: rect,
                        direction: d, proxy: proxy, ticket: ticket,
                        safeArea: knobConstraint
                    )
                    break
                }
            }

            // Loosen to card-only fit (pill may land on ticket
            // content) as a second fallback. Still prefer a non-
            // colliding choice — a pill on ticket content is fine,
            // a pill that crosses another target is not.
            if picked == nil {
                for d in order {
                    guard cardFitChecks(direction: d, rect: rect, size: proxy.size, label: labelText) else { continue }
                    let candidate = makePlacement(
                        element: element, label: labelText, rect: rect,
                        direction: d, proxy: proxy, ticket: ticket,
                        safeArea: knobConstraint
                    )
                    if !placed.contains(where: { placementsCollide($0, candidate) }) {
                        picked = candidate
                        break
                    }
                }
            }
            // Same loosening but accept collision when no non-
            // crossing card-fit direction exists. Collision resolver
            // gets a second chance afterwards.
            if picked == nil {
                for d in order {
                    guard cardFitChecks(direction: d, rect: rect, size: proxy.size, label: labelText) else { continue }
                    picked = makePlacement(
                        element: element, label: labelText, rect: rect,
                        direction: d, proxy: proxy, ticket: ticket,
                        safeArea: knobConstraint
                    )
                    break
                }
            }

            // Last resort — best-room direction even if pill exits the card.
            if picked == nil {
                let d = order.max(by: {
                    roomFor(direction: $0, rect: rect, size: proxy.size, label: labelText)
                        < roomFor(direction: $1, rect: rect, size: proxy.size, label: labelText)
                }) ?? .bottom
                picked = makePlacement(
                    element: element, label: labelText, rect: rect,
                    direction: d, proxy: proxy, ticket: ticket,
                    safeArea: knobConstraint
                )
            }

            if let p = picked { placed.append(p) }
        }

        return placed
    }

    /// One-stop builder for a `Placement`. Computes the knob point,
    /// the adaptive leader length and the pill bbox in one go so call
    /// sites stay short.
    private func makePlacement(
        element: TicketStyleVariant.Element,
        label labelText: String,
        rect: CGRect,
        direction: ColorTarget.Direction,
        proxy: GeometryProxy,
        ticket: CGRect,
        safeArea: CGRect?
    ) -> Placement {
        let rawKnob = pillKnobPosition(
            for: rect, direction: direction, cardSize: proxy.size
        )
        let knob = clampKnob(rawKnob, into: safeArea)
        let leader = adaptiveLeaderLength(
            for: direction,
            anchor: rect,
            ticket: ticket,
            cardSize: proxy.size,
            label: labelText
        )
        let bbox = pillBoundingBox(
            at: knob,
            direction: direction,
            label: labelText,
            leaderLength: leader
        )
        let leaderBBox = leaderBoundingBox(
            at: knob,
            direction: direction,
            leaderLength: leader
        )
        return Placement(
            element: element,
            label: labelText,
            rect: rect,
            direction: direction,
            knob: knob,
            leaderLength: leader,
            bbox: bbox,
            leaderBBox: leaderBBox
        )
    }

    /// Clamps a knob point into the supplied safe area. Used so the
    /// `.background` knob — which would otherwise sit on the
    /// silhouette's bounding rect — lands inside the visual interior
    /// of templates with notches / cutouts. A nil safe area is a
    /// no-op; smaller-than-knob safe areas degrade gracefully because
    /// `min`/`max` keep the result inside whatever box was given.
    private func clampKnob(_ point: CGPoint, into safeArea: CGRect?) -> CGPoint {
        guard let safeArea else { return point }
        return CGPoint(
            x: min(max(point.x, safeArea.minX), safeArea.maxX),
            y: min(max(point.y, safeArea.minY), safeArea.maxY)
        )
    }

    /// AABB of the leader stroke between the knob and the pill edge.
    /// Slightly inflated so AABB intersection reliably catches two
    /// leaders crossing at right angles (a 1pt stroke against a 1pt
    /// stroke can otherwise miss the intersection on sub-pixel
    /// boundaries).
    private func leaderBoundingBox(
        at knob: CGPoint,
        direction: ColorTarget.Direction,
        leaderLength: CGFloat
    ) -> CGRect {
        let strokeWidth: CGFloat = 3
        let half = strokeWidth / 2
        switch direction {
        case .top:
            return CGRect(
                x: knob.x - half,
                y: knob.y - leaderLength,
                width: strokeWidth,
                height: leaderLength
            )
        case .bottom:
            return CGRect(
                x: knob.x - half,
                y: knob.y,
                width: strokeWidth,
                height: leaderLength
            )
        case .left:
            return CGRect(
                x: knob.x - leaderLength,
                y: knob.y - half,
                width: leaderLength,
                height: strokeWidth
            )
        case .right:
            return CGRect(
                x: knob.x,
                y: knob.y - half,
                width: leaderLength,
                height: strokeWidth
            )
        }
    }

    /// Composite collision check: two placements collide if either of
    /// their pills overlap, their leaders cross, or one's leader runs
    /// through the other's pill. All three cases produce a visually
    /// "tangled" target.
    private func placementsCollide(_ a: Placement, _ b: Placement) -> Bool {
        if a.bbox.intersects(b.bbox)              { return true }
        if a.leaderBBox.intersects(b.leaderBBox)  { return true }
        if a.leaderBBox.intersects(b.bbox)        { return true }
        if b.leaderBBox.intersects(a.bbox)        { return true }
        return false
    }

    /// Walks the placement list looking for overlapping pairs. For
    /// each pair, attempts to move one of the two pills to a fresh
    /// direction that (a) still fits inside the card and (b) doesn't
    /// overlap any other pill. If neither pill can move, the
    /// collision is accepted and we move on. Bounded iteration so a
    /// pathological set of anchors can't loop forever.
    private func resolveCollisions(
        in placed: inout [Placement],
        safeArea: CGRect?,
        proxy: GeometryProxy,
        ticket: CGRect
    ) {
        let maxIterations = 8
        for _ in 0..<maxIterations {
            guard let pair = firstCollidingPair(in: placed) else { return }
            let (i, j) = pair
            if let alt = alternativeDirection(
                for: i, in: placed, proxy: proxy, ticket: ticket, safeArea: safeArea
            ) {
                placed[i] = alt
                continue
            }
            if let alt = alternativeDirection(
                for: j, in: placed, proxy: proxy, ticket: ticket, safeArea: safeArea
            ) {
                placed[j] = alt
                continue
            }
            // Neither can be moved — give up on this pair to avoid
            // looping. Other independent collisions still get a turn
            // because we re-scan from the top each iteration, but if
            // this pair is unresolvable we exit early.
            return
        }
    }

    private func firstCollidingPair(in placed: [Placement]) -> (Int, Int)? {
        for i in placed.indices {
            for j in (i + 1)..<placed.count {
                if placementsCollide(placed[i], placed[j]) {
                    return (i, j)
                }
            }
        }
        return nil
    }

    /// Tries every direction except the current one for the pill at
    /// `index`, looking for a non-colliding alternative. Tries strict
    /// fit first (pill clears ticket bounds), then loosens to a
    /// card-bounds-only fit. The looser pass matters when an anchor
    /// sits in a tight corner — strict fit may reject every
    /// direction, leaving the original crossing layout in place.
    /// Returns nil only when no direction in either pass clears the
    /// other pills.
    private func alternativeDirection(
        for index: Int,
        in placed: [Placement],
        proxy: GeometryProxy,
        ticket: CGRect,
        safeArea: CGRect?
    ) -> Placement? {
        let original = placed[index]
        let order: [ColorTarget.Direction] = [.top, .bottom, .left, .right]
        // Same constraint rule as the initial pass — only `.background`
        // wants its knob clamped into the silhouette's safe area.
        let knobConstraint = original.element == .background ? safeArea : nil

        // Pass 1 — strict fit (pill outside ticket).
        if let strict = nonCollidingAlternative(
            for: index, in: placed, order: order, proxy: proxy, ticket: ticket,
            safeArea: knobConstraint,
            predicate: { d in
                fits(direction: d, rect: original.rect, size: proxy.size,
                     label: original.label, ticket: ticket)
            }
        ) { return strict }

        // Pass 2 — card-bounds-only fit. A non-crossing layout that
        // lands a pill on the ticket is preferable to two crossing
        // pills, so accept it here.
        return nonCollidingAlternative(
            for: index, in: placed, order: order, proxy: proxy, ticket: ticket,
            safeArea: knobConstraint,
            predicate: { d in
                cardFitChecks(direction: d, rect: original.rect,
                              size: proxy.size, label: original.label)
            }
        )
    }

    private func nonCollidingAlternative(
        for index: Int,
        in placed: [Placement],
        order: [ColorTarget.Direction],
        proxy: GeometryProxy,
        ticket: CGRect,
        safeArea: CGRect?,
        predicate: (ColorTarget.Direction) -> Bool
    ) -> Placement? {
        let original = placed[index]
        for d in order where d != original.direction {
            guard predicate(d) else { continue }
            let candidate = makePlacement(
                element: original.element,
                label: original.label,
                rect: original.rect,
                direction: d,
                proxy: proxy,
                ticket: ticket,
                safeArea: safeArea
            )
            let collides = placed.enumerated().contains { offset, other in
                offset != index && placementsCollide(other, candidate)
            }
            guard !collides else { continue }
            return candidate
        }
        return nil
    }

    /// Stable iteration order — elements processed first get first
    /// dibs on directions and rarely have to fall back. Background
    /// goes last because its anchor spans the whole ticket and any
    /// direction works for it; better to give the more constrained
    /// anchors (small SF Symbols, single text glyphs) priority.
    private var placementOrder: [TicketStyleVariant.Element] {
        [.accent, .onAccent, .textPrimary,
         .tint1, .tint2, .tint3, .tint4, .tint5,
         .background]
    }

    /// AABB the **pill alone** occupies when the knob is at `knob`,
    /// the pill flows outward in `direction`, and the leader between
    /// them is `leaderLength` pt long. Excludes the leader stroke —
    /// leaders can cross each other visually without conflict, only
    /// pills need anti-collision.
    private func pillBoundingBox(
        at knob: CGPoint,
        direction: ColorTarget.Direction,
        label: String,
        leaderLength: CGFloat
    ) -> CGRect {
        let pillWidth = approxPillWidth(label: label)
        let pillHeight = approxPillHeight
        switch direction {
        case .top:
            return CGRect(
                x: knob.x - pillWidth / 2,
                y: knob.y - leaderLength - pillHeight,
                width: pillWidth,
                height: pillHeight
            )
        case .bottom:
            return CGRect(
                x: knob.x - pillWidth / 2,
                y: knob.y + leaderLength,
                width: pillWidth,
                height: pillHeight
            )
        case .left:
            return CGRect(
                x: knob.x - leaderLength - pillWidth,
                y: knob.y - pillHeight / 2,
                width: pillWidth,
                height: pillHeight
            )
        case .right:
            return CGRect(
                x: knob.x + leaderLength,
                y: knob.y - pillHeight / 2,
                width: pillWidth,
                height: pillHeight
            )
        }
    }

    // MARK: - Adaptive leader length

    /// Picks a leader length close to Figma's 41pt default, clamped
    /// down only when the card edge doesn't have room for it. We
    /// previously extended the leader far enough to push the pill
    /// outside the ticket bounds (so it sat in the card gutter, not
    /// on top of content) — that produced ~200pt leaders for
    /// centrally-anchored elements like the airplane glyph, which
    /// reads as disconnected. The pill is transient annotation
    /// chrome; landing it on ticket content during the style step is
    /// acceptable, and a short leader is much easier to follow.
    private func adaptiveLeaderLength(
        for direction: ColorTarget.Direction,
        anchor rect: CGRect,
        ticket _: CGRect,
        cardSize: CGSize,
        label: String
    ) -> CGFloat {
        let pillWidth = approxPillWidth(label: label)
        let pillHeight = approxPillHeight
        // Negative offset: the knob sits 3pt INSIDE the anchor edge
        // (matches `pillKnobPosition`) so the leader's effective
        // origin is inside the surface it points at, not 4pt outside
        // it as before.
        let knobGap: CGFloat = -3

        // Maximum leader the card edge allows after subtracting pill
        // size + cardInset — keeps the pill from kissing the card.
        let maxLeader: CGFloat
        switch direction {
        case .top:
            maxLeader = (rect.minY - knobGap) - cardInset - pillHeight
        case .bottom:
            maxLeader = (cardSize.height - cardInset) - (rect.maxY + knobGap) - pillHeight
        case .left:
            maxLeader = (rect.minX - knobGap) - cardInset - pillWidth
        case .right:
            maxLeader = (cardSize.width - cardInset) - (rect.maxX + knobGap) - pillWidth
        }

        let preferred: CGFloat = defaultLeaderLength
        let upperBound = max(approxLeaderLength, min(maxLeaderLength, maxLeader))
        return min(upperBound, max(approxLeaderLength, preferred))
    }

    /// Tucks the knob a few points INSIDE the anchor edge so the dot
    /// sits unambiguously on the surface it labels (e.g. for the
    /// `.background` anchor the dot lands on the ticket itself, not
    /// in the gap between the ticket and the pill). Earlier the knob
    /// sat OUTSIDE the anchor by 4pt; that produced a visible gap
    /// between the leader's tip and the ticket bottom for the
    /// background target on tall vertical templates.
    private func pillKnobPosition(
        for rect: CGRect,
        direction: ColorTarget.Direction,
        cardSize _: CGSize
    ) -> CGPoint {
        let edgeOffset: CGFloat = 3
        switch direction {
        case .top:    return CGPoint(x: rect.midX, y: rect.minY + edgeOffset)
        case .bottom: return CGPoint(x: rect.midX, y: rect.maxY - edgeOffset)
        case .left:   return CGPoint(x: rect.minX + edgeOffset, y: rect.midY)
        case .right:  return CGPoint(x: rect.maxX - edgeOffset, y: rect.midY)
        }
    }

    // MARK: - Pill sizing helpers

    /// Approximate fixed sizes for the pill chrome itself, used when
    /// the picker decides whether a direction has enough room. SF Pro
    /// regular at 11pt averages ~6.2pt per character; the 12pt swatch
    /// dot, 4pt gap and 16pt horizontal padding add a constant 32pt.
    private func approxPillWidth(label: String) -> CGFloat {
        CGFloat(label.count) * 6.2 + 32
    }

    private let approxPillHeight: CGFloat = 24
    /// Minimum leader length — the picker's `fits` check uses this
    /// when assessing whether a direction has enough room. Keep low
    /// (~10pt) so the picker doesn't reject directions where a short
    /// leader would do; the adaptive pass extends it as needed up to
    /// `maxLeaderLength`.
    private let approxLeaderLength: CGFloat = 10
    /// Hard ceiling on the adaptive leader length — beyond this the
    /// leader looks visually disconnected from its element.
    private let maxLeaderLength: CGFloat = 100
    /// Figma's stated leader length (`ColorTarget.leaderLength`
    /// default). Used as the preferred value; clamped down when the
    /// card edge is closer than that.
    private let defaultLeaderLength: CGFloat = 41
    /// Extra slack subtracted from the available room before we
    /// accept a fit — keeps the pill from kissing the card edge.
    private let cardInset: CGFloat = 8

    // MARK: - Direction picking

    /// True when the pill+leader fits inside the card with `cardInset`
    /// slack on both axes. Previously this also required the leader
    /// to be long enough to push the pill outside the ticket bounds
    /// — that produced very long leaders for centre-anchored
    /// elements, so we dropped it. Pills landing on ticket content is
    /// fine; they're transient annotation chrome on the style step.
    private func fits(
        direction: ColorTarget.Direction,
        rect: CGRect,
        size: CGSize,
        label: String,
        ticket _: CGRect
    ) -> Bool {
        cardFitChecks(direction: direction, rect: rect, size: size, label: label)
    }

    /// Card-bounds-only fit check (no ticket-overlap requirement).
    /// Used as a fallback when the strict `fits` rejects every
    /// direction — at least keep the pill inside the card.
    private func cardFitChecks(
        direction: ColorTarget.Direction,
        rect: CGRect,
        size: CGSize,
        label: String
    ) -> Bool {
        let pillWidth = approxPillWidth(label: label)
        switch direction {
        case .top:
            return rect.minY >= approxPillHeight + approxLeaderLength + cardInset
                && rect.midX - pillWidth / 2 >= cardInset
                && rect.midX + pillWidth / 2 <= size.width - cardInset
        case .bottom:
            return (size.height - rect.maxY) >= approxPillHeight + approxLeaderLength + cardInset
                && rect.midX - pillWidth / 2 >= cardInset
                && rect.midX + pillWidth / 2 <= size.width - cardInset
        case .left:
            return rect.minX >= pillWidth + approxLeaderLength + cardInset
                && rect.midY - approxPillHeight / 2 >= cardInset
                && rect.midY + approxPillHeight / 2 <= size.height - cardInset
        case .right:
            return (size.width - rect.maxX) >= pillWidth + approxLeaderLength + cardInset
                && rect.midY - approxPillHeight / 2 >= cardInset
                && rect.midY + approxPillHeight / 2 <= size.height - cardInset
        }
    }

    /// Signed clearance along the primary axis of the direction. Used
    /// to break ties when no direction fits cleanly — we still pick
    /// the one with the most positive room.
    private func roomFor(
        direction: ColorTarget.Direction,
        rect: CGRect,
        size: CGSize,
        label: String
    ) -> CGFloat {
        let pillWidth = approxPillWidth(label: label)
        switch direction {
        case .top:    return rect.minY - approxPillHeight - approxLeaderLength
        case .bottom: return (size.height - rect.maxY) - approxPillHeight - approxLeaderLength
        case .left:   return rect.minX - pillWidth - approxLeaderLength
        case .right:  return (size.width - rect.maxX) - pillWidth - approxLeaderLength
        }
    }

    // MARK: - Element → swatch / label

    private var resolved: TicketStyleVariant {
        let base = funnel.template?.resolveStyle(id: funnel.selectedStyleId)
            ?? TicketTemplateKind.studio.defaultStyle
        return base.applying(overrides: funnel.colorOverrides.isEmpty ? nil : funnel.colorOverrides)
    }

    private func color(for element: TicketStyleVariant.Element) -> Color {
        switch element {
        case .accent:      return resolved.accent
        case .onAccent:    return resolved.onAccent
        case .textPrimary: return resolved.textPrimary
        case .tint1:       return resolved.tint1 ?? resolved.swatch.accent
        case .tint2:       return resolved.tint2 ?? resolved.swatch.accent
        case .tint3:       return resolved.tint3 ?? resolved.swatch.accent
        case .tint4:       return resolved.tint4 ?? resolved.swatch.accent
        case .tint5:       return resolved.tint5 ?? resolved.swatch.accent
        case .background:
            // Override path: an explicit hex always wins.
            if let bg = resolved.backgroundColor { return bg }
            if let hex = funnel.colorOverrides[element.rawValue] {
                return Color(hex: hex)
            }
            // Fall back to the variant's swatch background — the
            // representative colour shown on the StyleTile preview
            // — so the pill matches the picked theme even when the
            // bg is rendered as an asset image.
            return resolved.swatch.background
        }
    }

    private func label(for element: TicketStyleVariant.Element) -> String {
        // Labels mirror the StyleStep collapsible titles so the pill
        // pointing at a region matches the control that drives it.
        if funnel.template == .prism {
            switch element {
            case .accent:      return String(localized: "accent")
            case .onAccent:    return String(localized: "accent text color")
            case .background:  return String(localized: "background")
            case .textPrimary: return String(localized: "text color")
            case .tint1:       return String(localized: "glow")
            case .tint2:       return String(localized: "midtone")
            case .tint3:       return String(localized: "highlight")
            case .tint4:       return String(localized: "tint 4")
            case .tint5:       return String(localized: "tint 5")
            }
        }
        if funnel.template == .terminal {
            switch element {
            case .accent:      return String(localized: "accent")
            case .onAccent:    return String(localized: "accent text color")
            case .background:  return String(localized: "background")
            case .textPrimary: return String(localized: "text color")
            case .tint1:       return String(localized: "backdrop")
            case .tint2:       return String(localized: "glow")
            case .tint3:       return String(localized: "midtone")
            case .tint4:       return String(localized: "highlight")
            case .tint5:       return String(localized: "accent")
            }
        }
        switch element {
        case .accent:      return String(localized: "accent")
        case .onAccent:    return String(localized: "accent text color")
        case .background:  return String(localized: "background")
        case .textPrimary: return String(localized: "text color")
        case .tint1:       return String(localized: "tint 1")
        case .tint2:       return String(localized: "tint 2")
        case .tint3:       return String(localized: "tint 3")
        case .tint4:       return String(localized: "tint 4")
        case .tint5:       return String(localized: "tint 5")
        }
    }
}

// MARK: - Anchored color target wrapper

/// Wraps a `ColorTarget` so `.position(x:y:)` lands the knob (the
/// dot at the leader's far end) on the supplied point, instead of
/// the ColorTarget's geometric centre.
///
/// SwiftUI's `.position` ignores `alignmentGuide` overrides on the
/// `.center` guide, so we can't shift the layout target that way.
/// Instead we anchor a 0×0 invisible point at the desired knob
/// location and overlay the actual ColorTarget aligned so its knob
/// edge lines up with that point. The ColorTarget then extends
/// outward from the knob in the chosen direction.
private struct AnchoredColorTarget: View {
    let color: Color
    let label: String
    let direction: ColorTarget.Direction
    var leaderLength: CGFloat = 41

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .overlay(alignment: anchorAlignment) {
                ColorTarget(
                    color: color,
                    label: label,
                    direction: direction,
                    leaderLength: leaderLength
                )
            }
    }

    /// Maps each direction to the alignment that puts the
    /// ColorTarget's knob edge on the 0×0 anchor:
    ///
    ///   - `.top`    pill above element → ColorTarget's bottom edge =
    ///     leader's knob → align to `.bottom` so it grows upward.
    ///   - `.bottom` pill below → top edge is the knob → `.top`.
    ///   - `.left`   pill on left → trailing edge is the knob →
    ///     `.trailing`.
    ///   - `.right`  pill on right → leading edge is the knob →
    ///     `.leading`.
    private var anchorAlignment: Alignment {
        switch direction {
        case .top:    return .bottom
        case .bottom: return .top
        case .left:   return .trailing
        case .right:  return .leading
        }
    }
}

