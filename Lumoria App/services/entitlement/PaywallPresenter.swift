//
//  PaywallPresenter.swift
//  Lumoria App
//
//  `Paywall.present(for:)` is the single entry point every gated CTA
//  calls. Skips presentation when the user already has Premium.
//

import SwiftUI
import Observation

enum Paywall {

    /// Whether the paywall sheet is currently presented. Bound from the
    /// app root via `@Environment` so any view can request the paywall
    /// without owning sheet state itself.
    @MainActor
    @Observable
    final class PresentationState {
        var trigger: PaywallTrigger? = nil
        var isPresented: Bool {
            get { trigger != nil }
            set { if !newValue { trigger = nil } }
        }
    }

    /// Present the paywall for the given trigger. No-op when the user
    /// is already Premium.
    @MainActor
    static func present(
        for trigger: PaywallTrigger,
        entitlement: EntitlementStore,
        state: PresentationState
    ) {
        guard !entitlement.hasPremium else { return }
        state.trigger = trigger
    }
}
