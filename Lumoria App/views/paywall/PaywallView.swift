//
//  PaywallView.swift
//  Lumoria App
//
//  Phase 1 placeholder. Phase 2 replaces this with the real plan-card +
//  hero-variant layout per the design spec.
//

import SwiftUI

struct PaywallView: View {
    let trigger: PaywallTrigger
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Premium")
                .font(.largeTitle.bold())
            Text(headline)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text("Phase 2 ships the real paywall here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }

    private var headline: String {
        switch trigger.variant {
        case .memoryLimit:    return "Unlimited memories with Premium."
        case .ticketLimit:    return "Unlimited tickets with Premium."
        case .mapSuite:       return "Timeline + map export with Premium."
        case .premiumContent: return "The full catalogue with Premium."
        }
    }
}
