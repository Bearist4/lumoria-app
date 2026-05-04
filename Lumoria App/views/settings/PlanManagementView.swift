//
//  PlanManagementView.swift
//  Lumoria App
//
//  Settings → Plan management. While EntitlementStore.kPaymentsEnabled
//  is false, this is a read-only status row: shows the early-adopter
//  badge for grandfathered users, or the free-plan blurb for everyone
//  else. The upgrade flow returns when payments ship.
//

import SwiftUI

struct PlanManagementView: View {
    @Environment(EntitlementStore.self) private var entitlement

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !entitlement.monetisationEnabled {
                    comingSoon
                } else {
                    statusRow
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var comingSoon: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Premium")
                .font(.largeTitle.bold())
            Text("Premium plans are coming soon. Today, every Lumoria account gets the full app for free.")
                .font(.body)
                .foregroundStyle(Color.Text.secondary)
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch entitlement.tier {
        case .grandfathered:
            HStack(alignment: .top, spacing: 12) {
                LumoriaPremiumBadge(style: .crown)
                Text("Early adopter — unlimited memories and tickets")
                    .font(.headline)
                    .foregroundStyle(Color.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                Text("Free plan")
                    .font(.title2.bold())
                Text("3 memories, 10 tickets")
                    .font(.body)
                    .foregroundStyle(Color.Text.secondary)
                Text("+1 memory or +2 tickets when your invite is redeemed")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.tertiary)
            }
        }
    }
}
