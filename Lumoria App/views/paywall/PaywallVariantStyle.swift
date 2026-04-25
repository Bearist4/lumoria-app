//
//  PaywallVariantStyle.swift
//  Lumoria App
//
//  Per-variant copy + accent colour. Shared by the hero compositions
//  and PaywallView so the four variants can't drift apart over time.
//

import SwiftUI

extension PaywallTrigger.Variant {

    /// Accent colour applied to the hero radial gradient and the lead
    /// shape of each composition.
    var accent: Color {
        switch self {
        case .memoryLimit:    return Color(red: 0.95, green: 0.51, blue: 0.55) // coral
        case .ticketLimit:    return Color(red: 0.50, green: 0.45, blue: 0.92) // indigo
        case .mapSuite:       return Color(red: 0.21, green: 0.74, blue: 0.78) // teal
        case .premiumContent: return Color(red: 0.95, green: 0.74, blue: 0.27) // amber
        }
    }

    var headline: String {
        switch self {
        case .memoryLimit:    return "Unlimited memories."
        case .ticketLimit:    return "Unlimited tickets."
        case .mapSuite:       return "Your trips, told."
        case .premiumContent: return "The full catalogue."
        }
    }

    var subhead: String {
        switch self {
        case .memoryLimit:
            return "Free covers 3 memories. Premium has no cap."
        case .ticketLimit:
            return "Free covers 5 tickets. Premium has no cap."
        case .mapSuite:
            return "Premium unlocks the timeline scrub, journey path, and full map export."
        case .premiumContent:
            return "Premium unlocks every template, every category, and the iOS sticker pack."
        }
    }
}
