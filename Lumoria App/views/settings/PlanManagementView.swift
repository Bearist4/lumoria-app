//
//  PlanManagementView.swift
//  Lumoria App
//
//  Settings → Plan management. Shows tier-driven copy when monetisation
//  is on; renders a "Premium coming soon" stub while the kill-switch
//  is off so the user sees the section exists without exposing buy
//  buttons.
//

import SwiftUI
import StoreKit

struct PlanManagementView: View {
    @Environment(EntitlementStore.self) private var entitlement
    @Environment(Paywall.PresentationState.self) private var paywallState

    @State private var purchase: PurchaseService

    init(entitlement: EntitlementStore) {
        self._purchase = State(initialValue: PurchaseService(entitlement: entitlement))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !entitlement.monetisationEnabled {
                    comingSoon
                } else {
                    tierCard
                    primaryAction
                }
                restoreButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Off state

    private var comingSoon: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Premium")
                .font(.largeTitle.bold())
            Text("Premium plans are coming soon. Today, every Lumoria account gets the full app for free.")
                .font(.body)
                .foregroundStyle(Color.Text.secondary)
        }
    }

    // MARK: - On state

    @ViewBuilder
    private var tierCard: some View {
        switch entitlement.tier {
        case .grandfathered:
            tierBlock(
                title: "Beta tester",
                body: "Premium is on the house, for life. Thanks for testing Lumoria."
            )
        case .lifetime:
            tierBlock(
                title: "Lifetime",
                body: "You bought Lumoria Lifetime. Premium stays unlocked forever."
            )
        case .subscriberInTrial(_, let exp):
            tierBlock(
                title: "Trial",
                body: "Free until \(exp.formatted(date: .abbreviated, time: .omitted))."
            )
        case .subscriber(let pid, let renews):
            let label = pid.contains("annual") ? "Annual" : "Monthly"
            tierBlock(
                title: label,
                body: "Renews \(renews.formatted(date: .abbreviated, time: .omitted))."
            )
        case .free:
            tierBlock(
                title: "Free",
                body: "Upgrade to unlock unlimited memories, tickets, the map suite, and more."
            )
        }
    }

    private func tierBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title2.bold())
            Text(body).font(.body).foregroundStyle(Color.Text.secondary)
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch entitlement.tier {
        case .free:
            Button {
                Paywall.present(
                    for: .upgradeFromSettings,
                    entitlement: entitlement,
                    state: paywallState
                )
            } label: {
                Text("See plans")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case .subscriber, .subscriberInTrial:
            if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                Link("Manage subscription", destination: url)
                    .font(.headline)
            }
        case .lifetime, .grandfathered:
            EmptyView()
        }
    }

    // MARK: - Restore (always visible)

    private var restoreButton: some View {
        Button("Restore purchases") {
            Task { _ = await purchase.restore() }
        }
        .font(.footnote)
        .foregroundStyle(.tint)
    }
}
