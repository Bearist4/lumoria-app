//
//  StyleAnchorKey.swift
//  Lumoria App
//
//  PreferenceKey templates use to publish where each recolorable
//  region sits within their geometry. The new-ticket style step's
//  preview tile reads these anchors so the decorative `ColorTarget`
//  pills snap their leader lines onto the exact element the user is
//  recoloring (e.g. the airplane glyph for `.accent`, the cabin-class
//  text for `.onAccent`).
//
//  Templates opt in by calling `.styleAnchor(_:)` once per region
//  they want to expose. The list of anchors is template-author
//  authority — Studio tags 4 elements; future templates can publish
//  any subset of `TicketStyleVariant.Element` cases (and only those
//  show targets). The preview reduces the dictionary by last-write-
//  wins so a duplicate tag is harmless during refactors.
//

import SwiftUI

struct StyleAnchorKey: PreferenceKey {

    /// Combined preference value: the per-element anchors templates
    /// publish via `.styleAnchor(_:)`, plus an optional `safeArea`
    /// rect a template can declare via `.styleSafeArea()` to keep
    /// `.background` knobs out of silhouette empty space (notches,
    /// rounded-corner gaps).
    struct Value {
        var elements: [TicketStyleVariant.Element: Anchor<CGRect>] = [:]
        var safeArea: Anchor<CGRect>? = nil
    }

    static var defaultValue: Value { Value() }

    static func reduce(value: inout Value, nextValue: () -> Value) {
        let next = nextValue()
        for (key, anchor) in next.elements {
            value.elements[key] = anchor
        }
        if let safeArea = next.safeArea {
            value.safeArea = safeArea
        }
    }
}

extension View {
    /// Tags the receiver as the anchor for a recolorable element.
    /// Templates call this once per region they expose, e.g.:
    ///
    /// ```swift
    /// Image(systemName: "airplane")
    ///     .foregroundStyle(style.accent)
    ///     .styleAnchor(.accent)
    /// ```
    ///
    /// The style-step preview tile reads the published bounds via
    /// `.overlayPreferenceValue(StyleAnchorKey.self)` and positions
    /// its `ColorTarget` pills so each leader line lands on the
    /// tagged region.
    func styleAnchor(_ element: TicketStyleVariant.Element) -> some View {
        anchorPreference(
            key: StyleAnchorKey.self,
            value: .bounds
        ) { anchor in
            var v = StyleAnchorKey.Value()
            v.elements = [element: anchor]
            return v
        }
    }

    /// Tags the receiver as the safe-knob region for the ticket's
    /// silhouette. Templates with notches, cutouts, or generous
    /// rounded corners should attach this to a clear sub-view sized
    /// to the visual interior so the style step's knob placement
    /// doesn't land on empty space (e.g. the iPhone-bezel notch on
    /// the vertical Studio template). When unset, knobs are placed
    /// against the `.background` rect verbatim.
    func styleSafeArea() -> some View {
        anchorPreference(
            key: StyleAnchorKey.self,
            value: .bounds
        ) { anchor in
            var v = StyleAnchorKey.Value()
            v.safeArea = anchor
            return v
        }
    }
}
