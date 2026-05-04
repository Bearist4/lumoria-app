//
//  LumoriaUpgradeIncentive.swift
//  Lumoria App
//
//  Upgrade-incentive pill from figma 2146:159524. Surfaces in the
//  Memories header when the user has run out of slots.
//

import SwiftUI

struct LumoriaUpgradeIncentive: View {
    enum Resource: Equatable {
        case memory
        case tickets
    }

    let resource: Resource

    var body: some View {
        Text(label)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.Feedback.Promotion.content)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.Feedback.Promotion.surface)
                    .overlay(
                        Capsule().stroke(Color.Feedback.Promotion.border, lineWidth: 1)
                    )
            )
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("Opens an invite a friend to unlock more slots."))
    }

    private var label: LocalizedStringKey {
        switch resource {
        case .memory:  return "Unlock a new memory"
        case .tickets: return "Unlock 2 new slots"
        }
    }
}

#if DEBUG
#Preview("Memory") {
    LumoriaUpgradeIncentive(resource: .memory)
        .padding()
        .background(Color.Background.default)
}

#Preview("Tickets") {
    LumoriaUpgradeIncentive(resource: .tickets)
        .padding()
        .background(Color.Background.default)
}
#endif
