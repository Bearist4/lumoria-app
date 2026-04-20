//
//  OnboardingCoordinator.swift
//  Lumoria App
//
//  Owns the state machine for the first-run tour: welcome sheet visibility,
//  persisted skip/complete flags, TipKit event donations, and the pending
//  memory that the Memories tab should auto-push after creation. Analytics
//  are emitted here so the UI stays dumb.
//

import Combine
import Foundation
import SwiftUI
import TipKit

@MainActor
final class OnboardingCoordinator: ObservableObject {

    // MARK: - Published UI state

    @Published var showWelcome: Bool = false
    @Published var pendingMemoryToOpen: Memory? = nil

    // MARK: - Persisted flags (UserDefaults-backed so tests can inject a
    // throwaway suite).

    @Published private(set) var welcomeSeen: Bool
    @Published private(set) var skipped: Bool
    @Published private(set) var completed: Bool

    /// Stamped when `start()` runs; used to compute the final duration.
    private(set) var startedAt: Date?

    private let defaults: UserDefaults

    private enum Keys {
        static let welcomeSeen = "onboarding.welcomeSeen"
        static let skipped     = "onboarding.skipped"
        static let completed   = "onboarding.completed"
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.welcomeSeen = defaults.bool(forKey: Keys.welcomeSeen)
        self.skipped     = defaults.bool(forKey: Keys.skipped)
        self.completed   = defaults.bool(forKey: Keys.completed)
    }

    // MARK: - Eligibility

    /// Called by `ContentView` after the stores' initial `.load()` completes.
    /// If the user already has any memories or tickets they're a returning
    /// user — silently mark onboarding completed so we never fire tips for
    /// them. Otherwise open the welcome sheet if they haven't seen it.
    func evaluateEligibility(memoriesCount: Int, ticketsCount: Int) {
        if completed || skipped { return }

        if memoriesCount > 0 || ticketsCount > 0 {
            setCompleted(true)
            return
        }

        if !welcomeSeen {
            showWelcome = true
            Analytics.track(.onboardingShown)
        }
    }

    // MARK: - User actions

    func start() async {
        setWelcomeSeen(true)
        startedAt = Date()
        Analytics.track(.onboardingStarted)
        // Donate before dismissing the sheet so the MemoryTip's rule
        // sees the event the moment the Memories view re-renders.
        await OnboardingEvents.onboardingStarted.donate()
        showWelcome = false
    }

    func skip() {
        setWelcomeSeen(true)
        setSkipped(true)
        showWelcome = false
        Analytics.track(.onboardingSkipped(atStep: .welcome))
    }

    func reset() async {
        setWelcomeSeen(false)
        setSkipped(false)
        setCompleted(false)
        startedAt = nil
        pendingMemoryToOpen = nil

        // Await the datastore wipe before re-opening the sheet so a
        // quick Start tap doesn't donate into a datastore that's about
        // to be cleared.
        try? Tips.resetDatastore()

        Analytics.track(.onboardingReplayed)
        showWelcome = true
    }

    // MARK: - Donations

    /// Called by `MemoriesStore` after a successful `create`.
    /// Only takes effect inside an active tour (post-start, pre-complete).
    func donateMemoryCreated(_ memory: Memory) {
        guard isInTour else { return }
        Analytics.track(.onboardingStepCompleted(step: .memory))
        pendingMemoryToOpen = memory
        Task { await OnboardingEvents.firstMemoryCreated.donate() }
    }

    /// Called by `SuccessStep.onAppear`.
    func donateTicketCreated() {
        guard isInTour else { return }
        Analytics.track(.onboardingStepCompleted(step: .ticket))
        Task { await OnboardingEvents.firstTicketCreated.donate() }
    }

    /// Called when the user taps the Export tile during the tour.
    func donateExportOpened() {
        guard isInTour else { return }
        Analytics.track(.onboardingStepCompleted(step: .export))
        Task { await OnboardingEvents.onboardingComplete.donate() }

        let duration: Int
        if let startedAt {
            duration = Int(Date().timeIntervalSince(startedAt))
        } else {
            duration = 0
        }
        setCompleted(true)
        Analytics.track(.onboardingCompleted(durationSeconds: duration))
    }

    // MARK: - Helpers

    private var isInTour: Bool { welcomeSeen && !skipped && !completed }

    private func setWelcomeSeen(_ value: Bool) {
        welcomeSeen = value
        defaults.set(value, forKey: Keys.welcomeSeen)
    }
    private func setSkipped(_ value: Bool) {
        skipped = value
        defaults.set(value, forKey: Keys.skipped)
    }
    private func setCompleted(_ value: Bool) {
        completed = value
        defaults.set(value, forKey: Keys.completed)
    }
}
