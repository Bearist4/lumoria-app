//
//  PlanCard.swift
//  Lumoria App
//
//  3-tile plan picker matching the Figma upgrade sheet layout.
//  Figma: 968:17975 (plan tile) + 969:20169 (sheet context)
//
//  Tile shape: 24pt corner radius, 16pt internal padding, radio button
//  on the left (44×44), pricing column to the right (price + period).
//  Selected → pink/50 #FFF0F7 background + filled radio.
//  Unselected → background/elevated #FAFAFA + outline radio.
//  Annual tile reserves a flexible right column for the "2 months free"
//  yellow chip.
//

import SwiftUI

enum PaywallPlan: String, Equatable, CaseIterable, Identifiable {
    case monthly  = "app.lumoria.premium.monthly"
    case annual   = "app.lumoria.premium.annual"
    case lifetime = "app.lumoria.premium.lifetime"

    var id: String { rawValue }

    var period: String {
        switch self {
        case .monthly:  return "Per month"
        case .annual:   return "Per year"
        case .lifetime: return "One-time purchase"
        }
    }
}

struct PlanCard: View {
    @Binding var selected: PaywallPlan
    /// Resolved (localised) display prices keyed by plan. Pulled from
    /// StoreKit `Product.displayPrice` when available; falls back to
    /// spec defaults.
    let prices: [PaywallPlan: String]

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
            HStack(spacing: 16) {
                radio(filled: isSelected)
                pricing(price: price, period: plan.period)
                if plan == .annual {
                    Spacer(minLength: 0)
                    MonthTag(text: "2 months free")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected
                          ? Color(red: 1.0, green: 0.941, blue: 0.969)   // pink/50
                          : Color(red: 0.980, green: 0.980, blue: 0.980)) // bg/elevated
            )
        }
        .buttonStyle(.plain)
    }

    // 44×44 radio button — outer circle stroke, filled inner dot when selected.
    private func radio(filled: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(Color.black, lineWidth: 2)
                .frame(width: 22, height: 22)
            if filled {
                Circle()
                    .fill(Color.black)
                    .frame(width: 13, height: 13)
            }
        }
        .frame(width: 44, height: 44)
    }

    private func pricing(price: String, period: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Title3/Emphasized: 20pt Semibold, lineHeight 25, kerning -0.45
            Text(price)
                .font(.system(size: 20, weight: .semibold))
                .kerning(-0.45)
                .foregroundStyle(.black)
            // Callout/Regular: 16pt Regular, lineHeight 21, kerning -0.31
            Text(period)
                .font(.system(size: 16))
                .kerning(-0.31)
                .foregroundStyle(Color(red: 0.451, green: 0.451, blue: 0.451)) // gray/500
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

#Preview {
    @Previewable @State var selected: PaywallPlan = .monthly
    PlanCard(selected: $selected, prices: [:])
        .padding(24)
}
