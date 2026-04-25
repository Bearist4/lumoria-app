//
//  PlanCard.swift
//  Lumoria App
//
//  3-tile plan picker. Tapping a tile updates the binding.
//  Figma: 968-17975
//

import SwiftUI

enum PaywallPlan: String, Equatable, CaseIterable, Identifiable {
    case monthly  = "app.lumoria.premium.monthly"
    case annual   = "app.lumoria.premium.annual"
    case lifetime = "app.lumoria.premium.lifetime"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly:  return "Monthly"
        case .annual:   return "Annual"
        case .lifetime: return "Lifetime"
        }
    }

    var isSubscription: Bool {
        switch self {
        case .monthly, .annual: return true
        case .lifetime:         return false
        }
    }
}

struct PlanCard: View {
    @Binding var selected: PaywallPlan
    /// Resolved (localised) display prices, keyed by the plan. Pulled
    /// from StoreKit `Product.displayPrice` when available, falling
    /// back to spec defaults.
    let prices: [PaywallPlan: String]
    /// Whether to show the "14 days free" tag on monthly/annual.
    let trialAvailable: Bool

    var body: some View {
        VStack(spacing: 12) {
            ForEach(PaywallPlan.allCases) { plan in
                tile(plan)
            }
        }
    }

    @ViewBuilder
    private func tile(_ plan: PaywallPlan) -> some View {
        let isSelected = plan == selected
        let price = prices[plan] ?? defaultPrice(plan)

        Button {
            selected = plan
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.headline)
                        if plan == .annual && !trialAvailable {
                            MonthTag(kind: .bestValue("Best value"))
                        }
                    }
                    Text(subtitle(plan, price: price))
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.secondary)
                }
                Spacer()
                leadingTag(plan)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.gray.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.Background.default)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func leadingTag(_ plan: PaywallPlan) -> some View {
        switch plan {
        case .monthly, .annual:
            if trialAvailable {
                MonthTag(kind: .trial("14 days free"))
            }
        case .lifetime:
            MonthTag(kind: .oneTime("One-time"))
        }
    }

    private func subtitle(_ plan: PaywallPlan, price: String) -> String {
        switch plan {
        case .monthly:  return "\(price) / month"
        case .annual:   return "\(price) / year"
        case .lifetime: return "\(price) once"
        }
    }

    private func defaultPrice(_ plan: PaywallPlan) -> String {
        switch plan {
        case .monthly:  return "$3.99"
        case .annual:   return "$24.99"
        case .lifetime: return "$59.99"
        }
    }
}

#Preview("Trial available") {
    @Previewable @State var selected: PaywallPlan = .annual
    PlanCard(
        selected: $selected,
        prices: [:],
        trialAvailable: true
    )
    .padding(24)
}

#Preview("Trial used") {
    @Previewable @State var selected: PaywallPlan = .annual
    PlanCard(
        selected: $selected,
        prices: [:],
        trialAvailable: false
    )
    .padding(24)
}
