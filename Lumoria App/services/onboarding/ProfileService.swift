//
//  ProfileService.swift
//  Lumoria App
//
//  Supabase CRUD wrapper for the public.profiles row that backs onboarding
//  state. See supabase/migrations/20260424000000_profiles.sql for schema.
//

import Foundation
import Supabase

struct Profile: Codable, Equatable, Sendable {
    let userId: UUID
    var showOnboarding: Bool
    var onboardingStep: OnboardingStep

    enum CodingKeys: String, CodingKey {
        case userId         = "user_id"
        case showOnboarding = "show_onboarding"
        case onboardingStep = "onboarding_step"
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
