//
//  EntitlementStore.swift
//  Lumoria App
//
//  Single source of truth for "is this user Premium". Fuses the
//  Supabase profile row (grandfather + DB-mirrored subscription state)
//  with the iOS-side StoreKit transaction stream.
//
//  Phase 1: read side only. trialAvailable always returns false here;
//  Phase 2 wires the real Product.SubscriptionInfo.isEligibleForIntroOffer
//  check alongside the purchase flow, since trial state only matters
//  once the paywall actually shows products.
//
//  Phase 2 also adds the write side: after a successful Product.purchase()
//  call we'll post the verified Transaction JWS to the
//  set_premium_from_transaction RPC, then call refresh() to pick up the
//  new is_premium / premium_expires_at on the profile.
//

import Foundation
import StoreKit
import Observation

private let kLifetimeProductId = "app.lumoria.premium.lifetime"
private let kMonthlyProductId  = "app.lumoria.premium.monthly"
private let kAnnualProductId   = "app.lumoria.premium.annual"

@MainActor
@Observable
final class EntitlementStore {

    private(set) var tier: EntitlementTier = .free
    private(set) var trialAvailable: Bool = false
    private(set) var inviteRewardKind: InviteRewardKind? = nil

    private let profileService: ProfileServicing

    init(profileService: ProfileServicing) {
        self.profileService = profileService
        // EntitlementStore is owned by the @main App as @State and lives
        // for the entire process lifetime, so we don't track this task
        // for cancellation — the app exit kills it.
        Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refresh()
            }
        }
    }

    var hasPremium: Bool { tier.hasPremium }

    /// Pull the latest profile row. Call on app launch, after sign-in,
    /// after a successful purchase, and after a manual "Restore
    /// purchases" tap.
    func refresh() async {
        do {
            let profile = try await profileService.fetch()
            self.tier = Self.tier(for: profile, now: Date())
            self.inviteRewardKind = profile.inviteRewardKind
        } catch {
            // No profile row → treat as free until we have one. Don't
            // surface the error here; the caller's auth flow handles it.
            self.tier = .free
            self.inviteRewardKind = nil
        }
    }

    /// Pure tier-resolution helper. Exposed for testing. `nonisolated`
    /// so unit tests can call it without main-actor hopping.
    nonisolated static func tier(for profile: Profile, now: Date) -> EntitlementTier {
        if profile.grandfatheredAt != nil {
            return .grandfathered
        }
        if profile.isPremium {
            // Lifetime: no expiry.
            if profile.premiumExpiresAt == nil {
                return .lifetime
            }
            // Active sub.
            if let exp = profile.premiumExpiresAt, exp > now {
                let pid = profile.premiumProductId ?? kAnnualProductId
                return .subscriber(productId: pid, renewsAt: exp)
            }
            // Expired sub: fall through to .free.
        }
        return .free
    }
}
