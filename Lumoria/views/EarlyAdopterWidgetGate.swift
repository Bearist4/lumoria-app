//
//  EarlyAdopterWidgetGate.swift
//  Lumoria (widget)
//
//  Wraps a widget's body. Reads `isEarlyAdopter` from the App Group
//  shared UserDefaults (mirrored by `EntitlementStore` on every
//  `refresh()`); when false, swaps the content for an upsell tile
//  whose tap-target deep-links into the main app's
//  EarlyAdopterPromoSheet via `lumoria://promo/early-adopter`.
//
//  Used by both `MemoryWidget` and `ProfileStatsWidget` — every
//  widget Lumoria ships is gated.
//

import SwiftUI
import WidgetKit

/// URL the gate routes to on tap. Lives here so the main app's
/// deep-link handler and the widget gate agree on one spelling.
let lumoriaEarlyAdopterPromoURL = URL(string: "lumoria://promo/early-adopter")!

struct EarlyAdopterWidgetGate<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isEarlyAdopter {
            content()
        } else {
            upsell
                .widgetURL(lumoriaEarlyAdopterPromoURL)
        }
    }

    private var isEarlyAdopter: Bool {
        WidgetSharedContainer.sharedDefaults.bool(
            forKey: WidgetSharedContainer.DefaultsKey.isEarlyAdopter
        )
    }

    private var upsell: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Color("Colors/Purple/400"))
                    .frame(width: 32, height: 32)
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Early adopter only")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.Text.primary)
                .multilineTextAlignment(.center)

            Text("Tap to claim a seat and unlock widgets.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Lumoria widgets are an early-adopter benefit"))
        .accessibilityHint(Text("Tap to open the early-adopter prompt"))
    }
}
