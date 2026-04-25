//
//  EntitlementStore.swift
//  Lumoria App
//
//  Single source of truth for "is this user Premium". Fuses the
//  Supabase profile row (grandfather + DB-mirrored subscription state)
//  with the iOS-side StoreKit transaction stream.
//
//  Phase 2 adds the monetisation kill-switch: while the
//  app_settings.monetisation_enabled flag is false, hasPremium is
//  forced to true so every paywall gate passes silently. Caps don't
//  fire (the server triggers also skip when the flag is off), the
//  paywall sheet never presents, and Plan management renders a
//  "coming soon" stub.
//
//  Phase 5 (ASSN2) will add server-side push verification of
//  Transaction state so the v1 client-trust posture closes.
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

    /// Pre-flag tier (what StoreKit + the profile say).
    private(set) var tier: EntitlementTier = .free
    /// Monetisation kill-switch state. False = free-for-all, no caps,
    /// no paywall.
    private(set) var monetisationEnabled: Bool = false
    private(set) var trialAvailable: Bool = false
    private(set) var inviteRewardKind: InviteRewardKind? = nil

    private let profileService: ProfileServicing
    private let appSettingsService: AppSettingsServicing

    init(
        profileService: ProfileServicing,
        appSettingsService: AppSettingsServicing
    ) {
        self.profileService = profileService
        self.appSettingsService = appSettingsService
        // EntitlementStore is owned by the @main App as @State and lives
        // for the entire process lifetime, so we don't track this task
        // for cancellation — the app exit kills it.
        Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refresh()
            }
        }
    }

    /// While monetisation is off (kill-switch in `app_settings`), every
    /// gate behaves as if the user already has Premium — caps don't
    /// fire, paywall never presents.
    var hasPremium: Bool {
        if !monetisationEnabled { return true }
        return tier.hasPremium
    }

    /// Pull the latest profile + app-settings rows. Call on app launch,
    /// after sign-in, after a successful purchase, and after a manual
    /// "Restore purchases" tap.
    func refresh() async {
        async let settingsTask: AppSettings? = {
            try? await appSettingsService.fetch()
        }()
        async let profileTask: Profile? = {
            try? await profileService.fetch()
        }()

        let settings = await settingsTask
        let profile  = await profileTask

        self.monetisationEnabled = settings?.monetisationEnabled ?? false

        if let profile {
            self.tier = Self.tier(for: profile, now: Date())
            self.inviteRewardKind = profile.inviteRewardKind
        } else {
            self.tier = .free
            self.inviteRewardKind = nil
        }
    }

    /// Resolved view for tests — pure, no I/O.
    struct Resolved: Equatable {
        let tier: EntitlementTier
        let hasPremium: Bool
    }

    nonisolated static func resolved(
        profile: Profile,
        monetisationEnabled: Bool,
        now: Date
    ) -> Resolved {
        let tier = tier(for: profile, now: now)
        let has = !monetisationEnabled || tier.hasPremium
        return Resolved(tier: tier, hasPremium: has)
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
