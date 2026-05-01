//
//  OnboardingFunnelDraftStore.swift
//  Lumoria App
//
//  Codable snapshot + UserDefaults storage for the in-progress new-ticket
//  funnel during the onboarding tutorial. Lets the resume path drop the
//  user back at the exact funnel step (and re-populate the forms) on a
//  cold launch instead of restarting the funnel from the category picker.
//

import Foundation

/// Snapshot of `NewTicketFunnel` state captured during onboarding.
struct OnboardingFunnelDraft: Codable {
    var step: NewTicketStep
    var category: TicketCategory?
    var template: TicketTemplateKind?
    var orientation: TicketOrientation
    var form: FlightFormInput
    var trainForm: TrainFormInput
    var eventForm: EventFormInput
    /// Optional so old drafts that pre-date the Eurovision template
    /// keep decoding cleanly — missing key resolves to nil and the
    /// funnel falls back to a default `EurovisionFormInput`.
    var eurovisionForm: EurovisionFormInput?
    var undergroundForm: UndergroundFormInput
    var selectedStyleId: String?
    /// Set once the ticket has been persisted (success / allDone /
    /// exportOrAddMemory steps). Non-nil means the resume path can
    /// re-fetch this ticket and jump straight to the success step.
    var createdTicketId: UUID?
}

/// UserDefaults-backed persistence for `OnboardingFunnelDraft`. Single
/// JSON blob under one key — payload is small (no images, mostly
/// strings + dates).
enum OnboardingFunnelDraftStore {

    private static let key = "onboarding.funnelDraft"

    static func load() -> OnboardingFunnelDraft? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(OnboardingFunnelDraft.self, from: data)
        } catch {
            // Schema drift or corruption — drop the broken blob so the
            // user gets a clean slate next time instead of a recurring
            // decode error.
            print("[OnboardingFunnelDraftStore] decode failed:", error)
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
    }

    static func save(_ draft: OnboardingFunnelDraft) {
        do {
            let data = try JSONEncoder().encode(draft)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("[OnboardingFunnelDraftStore] encode failed:", error)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
