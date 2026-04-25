//
//  PaywallHero.swift
//  Lumoria App
//
//  Dispatcher view — picks the right composition by variant. The
//  hero block sits at the top of PaywallView; below it the rest of
//  the paywall (plan card / CTA / restore / trust copy) stays
//  identical across variants.
//

import SwiftUI

struct PaywallHero: View {
    let variant: PaywallTrigger.Variant

    var body: some View {
        ZStack {
            // Soft radial gradient backdrop in the variant accent.
            RadialGradient(
                colors: [variant.accent.opacity(0.25), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 240
            )
            .frame(height: 280)
            .blur(radius: 20)
            .allowsHitTesting(false)

            VStack(spacing: 16) {
                composition
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)

                Text(variant.headline)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(variant.subhead)
                    .font(.title3)
                    .foregroundStyle(Color.Text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.top, 24)
        }
    }

    @ViewBuilder
    private var composition: some View {
        switch variant {
        case .memoryLimit:    MemoryLimitHero()
        case .ticketLimit:    TicketLimitHero()
        case .mapSuite:       MapSuiteHero()
        case .premiumContent: PremiumContentHero()
        }
    }
}

#Preview("memoryLimit") {
    PaywallHero(variant: .memoryLimit).padding(24)
}

#Preview("ticketLimit") {
    PaywallHero(variant: .ticketLimit).padding(24)
}

#Preview("mapSuite") {
    PaywallHero(variant: .mapSuite).padding(24)
}

#Preview("premiumContent") {
    PaywallHero(variant: .premiumContent).padding(24)
}
