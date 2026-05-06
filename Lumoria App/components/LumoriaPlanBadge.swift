//
//  LumoriaPlanBadge.swift
//  Lumoria App
//
//  Capsule status pill for the user's plan/seat tier. Sits next to
//  the user's name in the settings profile row and on the profile
//  screen. Distinct from `LumoriaPremiumBadge` (crown disc) — that one
//  marks individual premium-locked controls; this one labels the whole
//  account.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2152-162298
//

import SwiftUI

struct LumoriaPlanBadge: View {
    enum Tier: Equatable {
        case free
        case earlyAdopter

        var label: LocalizedStringKey {
            switch self {
            case .free:         return "Free"
            case .earlyAdopter: return "Early adopter"
            }
        }

        var background: Color {
            switch self {
            case .free:         return Color("Colors/Opacity/Black/regular/5")
            case .earlyAdopter: return Color("Colors/Purple/300")
            }
        }

        var foreground: Color {
            switch self {
            case .free:         return Color.Text.primary
            case .earlyAdopter: return .white
            }
        }
    }

    let tier: Tier

    var body: some View {
        Text(tier.label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tier.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(tier.background))
            .accessibilityLabel(Text(tier.label))
    }
}

#if DEBUG
#Preview("Free") {
    LumoriaPlanBadge(tier: .free)
        .padding()
        .background(Color.Background.default)
}

#Preview("Early adopter") {
    LumoriaPlanBadge(tier: .earlyAdopter)
        .padding()
        .background(Color.Background.default)
}
#endif
