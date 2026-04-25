//
//  EntitlementTier.swift
//  Lumoria App
//
//  What kind of access the user has. Drives the Plan management screen
//  copy and the paywall trial-vs-no-trial variant choice.
//

import Foundation

enum EntitlementTier: Equatable, Sendable {
    case grandfathered
    case lifetime
    case subscriberInTrial(productId: String, expiresAt: Date)
    case subscriber(productId: String, renewsAt: Date)
    case free

    var hasPremium: Bool {
        switch self {
        case .grandfathered, .lifetime, .subscriberInTrial, .subscriber:
            return true
        case .free:
            return false
        }
    }
}
