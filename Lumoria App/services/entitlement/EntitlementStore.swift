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
import Supabase
import WidgetKit

private let kLifetimeProductId = "app.lumoria.premium.lifetime"
private let kMonthlyProductId  = "app.lumoria.premium.monthly"
private let kAnnualProductId   = "app.lumoria.premium.annual"

@MainActor
@Observable
final class EntitlementStore {

    /// Master toggle for any payment-related UI. False = no purchase
    /// paths anywhere in the app; the limit-reached paywall renders the
    /// invite-only landing instead. Flip to true once StoreKit ships.
    static let kPaymentsEnabled = false

    /// Pre-flag tier (what StoreKit + the profile say).
    private(set) var tier: EntitlementTier = .free
    /// Monetisation kill-switch state. False = free-for-all, no caps,
    /// no paywall.
    private(set) var monetisationEnabled: Bool = false
    private(set) var trialAvailable: Bool = false
    private(set) var inviteRewardKind: InviteRewardKind? = nil
    /// Last-known seats remaining (0..300). Nil before the first
    /// `loadEarlyAdopterSeats()` resolves. Refreshed eagerly when the
    /// promo sheet appears and after every successful claim/revoke.
    private(set) var earlyAdopterSeatsRemaining: Int? = nil
    /// Hard cap baked into the migration RPC. Mirrored client-side so
    /// callers can render "X / 300" without an extra round trip.
    static let earlyAdopterSeatCap: Int = 300
    /// "Early adopter" is the user-facing name for a grandfathered
    /// seat — same column (`profiles.grandfathered_at`), same caps
    /// bypass, just self-claimed instead of admin-issued. Drives the
    /// plan badge label, the Settings row swap (Become → Manage), and
    /// the Research entry's visibility.
    var isEarlyAdopter: Bool { tier == .grandfathered }

    /// Mirrors `isEarlyAdopter` into the App Group `UserDefaults` so
    /// the widget process can gate its own content. Called from
    /// `refresh()` (and the claim / revoke paths via refresh) — every
    /// path that mutates `tier` flows through here. Also bumps
    /// `WidgetCenter` so any installed widgets re-render against the
    /// new value immediately.
    private func mirrorEarlyAdopterToWidgets() {
        let current = isEarlyAdopter
        let stored = WidgetSharedContainer.sharedDefaults.bool(
            forKey: WidgetSharedContainer.DefaultsKey.isEarlyAdopter
        )
        guard stored != current else { return }
        WidgetSharedContainer.sharedDefaults.set(
            current,
            forKey: WidgetSharedContainer.DefaultsKey.isEarlyAdopter
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

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
        mirrorEarlyAdopterToWidgets()
    }

    // MARK: - Early-adopter seat

    /// Errors surfaced from the early-adopter RPCs. Mapped from the
    /// PostgREST error string so callers can branch on the cap-reached
    /// case without inspecting raw error text.
    enum EarlyAdopterError: Error, Equatable {
        case seatsExhausted
        case underlying(String)
    }

    /// Pull the current seat count from
    /// `early_adopter_seats_remaining()`. Cheap — runs a single
    /// COUNT(*) on profiles. Call when the promo sheet appears.
    func loadEarlyAdopterSeats() async {
        do {
            let remaining: Int = try await supabase
                .rpc("early_adopter_seats_remaining")
                .execute()
                .value
            self.earlyAdopterSeatsRemaining = remaining
        } catch {
            print("[EntitlementStore] loadEarlyAdopterSeats failed:", error)
        }
    }

    /// Claim a seat for the signed-in user. Idempotent server-side, so
    /// double-tap is safe. Throws `.seatsExhausted` when the cap is
    /// full so the UI can swap to a sold-out state. On success the
    /// tier flips to `.grandfathered` after a `refresh()` round trip.
    func claimEarlyAdopterSeat() async throws {
        do {
            _ = try await supabase
                .rpc("claim_early_adopter_seat")
                .execute()
            await refresh()
            await loadEarlyAdopterSeats()
        } catch {
            if Self.isSeatsExhausted(error) {
                await loadEarlyAdopterSeats()
                throw EarlyAdopterError.seatsExhausted
            }
            throw EarlyAdopterError.underlying(error.localizedDescription)
        }
    }

    /// Revoke the caller's seat — frees it for someone else and flips
    /// the badge / Research row back off. RPC clears `grandfathered_at`
    /// server-side; `refresh()` re-resolves the tier client-side.
    func revokeEarlyAdopterSeat() async throws {
        do {
            _ = try await supabase
                .rpc("revoke_early_adopter_seat")
                .execute()
            await refresh()
            await loadEarlyAdopterSeats()
        } catch {
            throw EarlyAdopterError.underlying(error.localizedDescription)
        }
    }

    private static func isSeatsExhausted(_ error: Error) -> Bool {
        // Supabase wraps Postgres `RAISE EXCEPTION 'no_seats_remaining'`
        // into a localizedDescription that contains the literal string.
        // Cheaper than parsing the JSON envelope.
        error.localizedDescription.contains("no_seats_remaining")
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

#if DEBUG
    /// Test-only constructor that skips ProfileService / AppSettingsService.
    /// Lets unit tests build a deterministic store without touching Supabase.
    static func previewInstance(
        tier: EntitlementTier,
        monetisationEnabled: Bool,
        inviteRewardKind: InviteRewardKind? = nil
    ) -> EntitlementStore {
        let store = EntitlementStore(
            profileService: PreviewEntitlementProfileService(),
            appSettingsService: PreviewEntitlementAppSettingsService()
        )
        store.tier = tier
        store.monetisationEnabled = monetisationEnabled
        store.inviteRewardKind = inviteRewardKind
        return store
    }
#endif
}

#if DEBUG
private final class PreviewEntitlementProfileService: ProfileServicing, @unchecked Sendable {
    func fetch() async throws -> Profile { throw ProfileServiceError.notFound }
    func setStep(_ step: OnboardingStep) async throws {}
    func setShowOnboarding(_ value: Bool) async throws {}
    func replay() async throws {}
}

private final class PreviewEntitlementAppSettingsService: AppSettingsServicing, @unchecked Sendable {
    func fetch() async throws -> AppSettings {
        throw NSError(domain: "preview", code: 0)
    }
}
#endif
