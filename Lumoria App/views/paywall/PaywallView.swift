//
//  PaywallView.swift
//  Lumoria App
//
//  Real paywall layout. Phase 2 ships a single default hero per the
//  trigger variant; Phase 3 splits the hero into 4 personalised blocks.
//
//  Figma — default: 969-20169 · trial: 969-20173 · trial used: 969-20171
//

import SwiftUI

struct PaywallView: View {
    let trigger: PaywallTrigger
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementStore.self) private var entitlement
    @State private var purchase: PurchaseService
    @State private var selected: PaywallPlan = .annual
    @State private var error: String? = nil

    init(trigger: PaywallTrigger, entitlement: EntitlementStore) {
        self.trigger = trigger
        self._purchase = State(initialValue: PurchaseService(entitlement: entitlement))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                hero
                planCard
                primaryCTA
                trustCopy
                restoreLink
                if let error { errorBanner(error) }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
        .task {
            await purchase.loadProducts()
        }
    }

    // MARK: - Hero (Phase 3 — per-variant SwiftUI compositions)

    private var hero: some View {
        PaywallHero(variant: trigger.variant)
    }

    // MARK: - Plan card

    @ViewBuilder
    private var planCard: some View {
        let prices: [PaywallPlan: String] = {
            var map: [PaywallPlan: String] = [:]
            for plan in PaywallPlan.allCases {
                if let p = purchase.displayPrice(for: plan) {
                    map[plan] = p
                }
            }
            return map
        }()
        PlanCard(
            selected: $selected,
            prices: prices,
            trialAvailable: entitlement.trialAvailable
        )
    }

    // MARK: - CTA

    private var primaryCTA: some View {
        Button {
            Task {
                if await purchase.purchase(selected) {
                    dismiss()
                } else if let f = purchase.lastError {
                    error = description(of: f)
                }
            }
        } label: {
            Text(ctaText)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(purchase.isPurchasing)
    }

    private var ctaText: String {
        if selected == .lifetime {
            return "Buy lifetime"
        }
        if entitlement.trialAvailable {
            return "Start free trial"
        }
        return "Subscribe"
    }

    private var trustCopy: some View {
        VStack(spacing: 4) {
            Text(trustLine)
                .font(.footnote)
                .foregroundStyle(Color.Text.secondary)
                .multilineTextAlignment(.center)
            Text("By continuing you agree to our Terms and Privacy.")
                .font(.caption2)
                .foregroundStyle(Color.Text.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var trustLine: String {
        if selected == .lifetime {
            return "One-time purchase. No subscription."
        }
        if entitlement.trialAvailable {
            return "Free for 14 days, then \(priceTrailer). Cancel anytime."
        }
        return "Cancel anytime in Settings."
    }

    private var priceTrailer: String {
        guard let p = purchase.displayPrice(for: selected) else {
            return selected == .annual ? "$24.99/year" : "$3.99/month"
        }
        return selected == .annual ? "\(p)/year" : "\(p)/month"
    }

    // MARK: - Restore

    private var restoreLink: some View {
        Button("Restore purchases") {
            Task { _ = await purchase.restore() }
        }
        .font(.footnote)
        .foregroundStyle(.tint)
    }

    private func errorBanner(_ msg: String) -> some View {
        Text(msg)
            .font(.footnote)
            .foregroundStyle(Color.Feedback.Danger.icon)
            .multilineTextAlignment(.center)
    }

    private func description(of failure: PurchaseService.Failure) -> String {
        switch failure {
        case .notSignedIn:        return "You need to be signed in."
        case .verificationFailed: return "Couldn't verify the purchase. Try again."
        case .rpcFailed(let m):   return "Server didn't accept the purchase. (\(m))"
        case .storeKitError(let m): return m
        }
    }
}

// MARK: - Previews

#if DEBUG

/// Stub profile service used by the canvas previews. Returns a free
/// (non-grandfathered, non-premium) profile so the paywall renders in
/// its most common state.
private final class PreviewPaywallProfileService: ProfileServicing, @unchecked Sendable {
    func fetch() async throws -> Profile {
        Profile(
            userId: UUID(),
            showOnboarding: false,
            onboardingStep: .done
        )
    }
    func setStep(_ step: OnboardingStep) async throws {}
    func setShowOnboarding(_ value: Bool) async throws {}
    func replay() async throws {}
}

/// Stub app-settings service. `monetisationEnabled = true` keeps the
/// preview in the post-go-live state (so the paywall actually presents
/// content rather than the "coming soon" stub). Switch to false to
/// see how the paywall body looks under the kill-switch.
private final class PreviewPaywallAppSettingsService: AppSettingsServicing, @unchecked Sendable {
    let monetisationEnabled: Bool
    init(monetisationEnabled: Bool) {
        self.monetisationEnabled = monetisationEnabled
    }
    func fetch() async throws -> AppSettings {
        AppSettings(
            id: "singleton",
            monetisationEnabled: monetisationEnabled,
            updatedAt: nil
        )
    }
}

/// Build an EntitlementStore wired to stub services. Only used by the
/// previews below — it shares the same observable type the live app
/// uses so the paywall renders identically.
@MainActor
private func previewEntitlement() -> EntitlementStore {
    let store = EntitlementStore(
        profileService: PreviewPaywallProfileService(),
        appSettingsService: PreviewPaywallAppSettingsService(monetisationEnabled: true)
    )
    Task { await store.refresh() }
    return store
}

#Preview("memoryLimit") {
    let entitlement = previewEntitlement()
    return PaywallView(trigger: .memoryLimit, entitlement: entitlement)
        .environment(entitlement)
}

#Preview("ticketLimit") {
    let entitlement = previewEntitlement()
    return PaywallView(trigger: .ticketLimit, entitlement: entitlement)
        .environment(entitlement)
}

#Preview("mapSuite") {
    let entitlement = previewEntitlement()
    return PaywallView(trigger: .timelineLocked, entitlement: entitlement)
        .environment(entitlement)
}

#Preview("premiumContent") {
    let entitlement = previewEntitlement()
    return PaywallView(trigger: .upgradeFromSettings, entitlement: entitlement)
        .environment(entitlement)
}

#endif
