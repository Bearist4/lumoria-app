//
//  ProfileService.swift
//  Lumoria App
//
//  Supabase CRUD wrapper for the public.profiles row that backs onboarding
//  state. See supabase/migrations/20260424000000_profiles.sql for schema.
//

import Foundation
import Supabase

enum InviteRewardKind: String, Codable, Equatable, Sendable {
    case memory  = "memory"
    case tickets = "tickets"
}

struct Profile: Codable, Equatable, Sendable {
    let userId: UUID
    var showOnboarding: Bool
    var onboardingStep: OnboardingStep

    // Entitlement / paywall state. Server-managed — clients can read
    // their own row but cannot write these columns directly (see the
    // profiles_protect_managed_columns trigger).
    var grandfatheredAt: Date?
    var isPremium: Bool
    var premiumExpiresAt: Date?
    var premiumProductId: String?
    var premiumTransactionId: String?

    // Invite reward (Phase 1 foundation; Phase 4 wires the picker UI).
    var inviteRewardKind: InviteRewardKind?
    var inviteRewardClaimedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId                = "user_id"
        case showOnboarding        = "show_onboarding"
        case onboardingStep        = "onboarding_step"
        case grandfatheredAt       = "grandfathered_at"
        case isPremium             = "is_premium"
        case premiumExpiresAt      = "premium_expires_at"
        case premiumProductId      = "premium_product_id"
        case premiumTransactionId  = "premium_transaction_id"
        case inviteRewardKind      = "invite_reward_kind"
        case inviteRewardClaimedAt = "invite_reward_claimed_at"
    }

    init(
        userId: UUID,
        showOnboarding: Bool,
        onboardingStep: OnboardingStep,
        grandfatheredAt: Date? = nil,
        isPremium: Bool = false,
        premiumExpiresAt: Date? = nil,
        premiumProductId: String? = nil,
        premiumTransactionId: String? = nil,
        inviteRewardKind: InviteRewardKind? = nil,
        inviteRewardClaimedAt: Date? = nil
    ) {
        self.userId = userId
        self.showOnboarding = showOnboarding
        self.onboardingStep = onboardingStep
        self.grandfatheredAt = grandfatheredAt
        self.isPremium = isPremium
        self.premiumExpiresAt = premiumExpiresAt
        self.premiumProductId = premiumProductId
        self.premiumTransactionId = premiumTransactionId
        self.inviteRewardKind = inviteRewardKind
        self.inviteRewardClaimedAt = inviteRewardClaimedAt
    }
}

enum ProfileServiceError: Error {
    case notAuthenticated
    case notFound
    case underlying(Error)
}

protocol ProfileServicing: AnyObject, Sendable {
    func fetch() async throws -> Profile
    func setStep(_ step: OnboardingStep) async throws
    func setShowOnboarding(_ value: Bool) async throws
    func replay() async throws
}

final class ProfileService: ProfileServicing, @unchecked Sendable {

    func fetch() async throws -> Profile {
        guard let uid = supabase.auth.currentUser?.id else {
            throw ProfileServiceError.notAuthenticated
        }
        do {
            let row: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("user_id", value: uid.uuidString)
                .single()
                .execute()
                .value
            return row
        } catch {
            // PostgREST returns PGRST116 when `.single()` matches zero rows.
            // Map to .notFound so the coordinator can default to a fresh tour.
            let ns = error as NSError
            if ns.localizedDescription.contains("PGRST116") {
                throw ProfileServiceError.notFound
            }
            throw ProfileServiceError.underlying(error)
        }
    }

    func setStep(_ step: OnboardingStep) async throws {
        guard let uid = supabase.auth.currentUser?.id else {
            throw ProfileServiceError.notAuthenticated
        }
        try await supabase
            .from("profiles")
            .update(["onboarding_step": step.rawValue])
            .eq("user_id", value: uid.uuidString)
            .execute()
    }

    func setShowOnboarding(_ value: Bool) async throws {
        guard let uid = supabase.auth.currentUser?.id else {
            throw ProfileServiceError.notAuthenticated
        }
        struct Update: Encodable { let show_onboarding: Bool }
        try await supabase
            .from("profiles")
            .update(Update(show_onboarding: value))
            .eq("user_id", value: uid.uuidString)
            .execute()
    }

    func replay() async throws {
        guard let uid = supabase.auth.currentUser?.id else {
            throw ProfileServiceError.notAuthenticated
        }
        struct Update: Encodable {
            let show_onboarding: Bool
            let onboarding_step: String
        }
        try await supabase
            .from("profiles")
            .update(Update(
                show_onboarding: true,
                onboarding_step: OnboardingStep.welcome.rawValue
            ))
            .eq("user_id", value: uid.uuidString)
            .execute()
    }
}
