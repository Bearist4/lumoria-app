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

    // MARK: - Hero (default for Phase 2)

    private var hero: some View {
        VStack(spacing: 16) {
            Image(systemName: heroSymbol)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.top, 24)
            Text(headline)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(subhead)
                .font(.title3)
                .foregroundStyle(Color.Text.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var heroSymbol: String {
        switch trigger.variant {
        case .memoryLimit:    return "rectangle.stack.fill"
        case .ticketLimit:    return "ticket.fill"
        case .mapSuite:       return "map.fill"
        case .premiumContent: return "sparkles"
        }
    }

    private var headline: String {
        switch trigger.variant {
        case .memoryLimit:    return "Unlimited memories."
        case .ticketLimit:    return "Unlimited tickets."
        case .mapSuite:       return "Your trips, told."
        case .premiumContent: return "The full catalogue."
        }
    }

    private var subhead: String {
        switch trigger.variant {
        case .memoryLimit:
            return "Free covers 3 memories. Premium has no cap."
        case .ticketLimit:
            return "Free covers 5 tickets. Premium has no cap."
        case .mapSuite:
            return "Premium unlocks the timeline scrub and full map export."
        case .premiumContent:
            return "Premium unlocks every template, every category, and the iOS sticker pack."
        }
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
