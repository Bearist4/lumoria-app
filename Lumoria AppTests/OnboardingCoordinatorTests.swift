//
//  OnboardingCoordinatorTests.swift
//  Lumoria AppTests
//
//  State-transition tests for the onboarding coordinator. Does not exercise
//  TipKit donations (those require a real Tips.Event datastore) — instead
//  asserts on the coordinator's own published state + flags.
//

import Foundation
import Testing
@testable import Lumoria_App

@MainActor
@Suite("OnboardingCoordinator")
struct OnboardingCoordinatorTests {

    // Each test uses a unique UserDefaults suite so persisted reads don't
    // leak between tests. The coordinator accepts a UserDefaults instance
    // in its initializer for this reason.
    private func fresh() -> OnboardingCoordinator {
        let suiteName = "onboarding.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return OnboardingCoordinator(defaults: defaults)
    }

    @Test("fresh user with zero data shows welcome")
    func eligibilityFreshUser() async {
        let c = fresh()
        c.evaluateEligibility(memoriesCount: 0, ticketsCount: 0)
        #expect(c.showWelcome == true)
        #expect(c.completed == false)
        #expect(c.skipped == false)
    }

    @Test("existing user with memories is silently completed")
    func eligibilityExistingUser() async {
        let c = fresh()
        c.evaluateEligibility(memoriesCount: 2, ticketsCount: 0)
        #expect(c.showWelcome == false)
        #expect(c.completed == true)
    }

    @Test("skip sets flags and suppresses future evaluations")
    func skipPath() async {
        let c = fresh()
        c.evaluateEligibility(memoriesCount: 0, ticketsCount: 0)
        c.skip()
        #expect(c.showWelcome == false)
        #expect(c.skipped == true)
        #expect(c.welcomeSeen == true)

        c.evaluateEligibility(memoriesCount: 0, ticketsCount: 0)
        #expect(c.showWelcome == false)
    }

    @Test("start sets welcomeSeen and stamps startedAt")
    func startPath() async {
        let c = fresh()
        c.evaluateEligibility(memoriesCount: 0, ticketsCount: 0)
        await c.start()
        #expect(c.welcomeSeen == true)
        #expect(c.showWelcome == false)
        #expect(c.startedAt != nil)
    }

    @Test("reset clears flags and reopens welcome")
    func resetPath() async {
        let c = fresh()
        c.evaluateEligibility(memoriesCount: 0, ticketsCount: 0)
        await c.start()
        c.donateExportOpened()
        #expect(c.completed == true)

        await c.reset()
        #expect(c.welcomeSeen == false)
        #expect(c.completed == false)
        #expect(c.skipped == false)
        #expect(c.showWelcome == true)
    }

    @Test("donations only count during an active tour")
    func donationsGatedByStart() async {
        let c = fresh()
        let memoryA = Memory(
            id: UUID(), userId: UUID(),
            name: "m", colorFamily: "sky", emoji: nil,
            createdAt: .now, updatedAt: .now
        )
        c.donateMemoryCreated(memoryA)
        #expect(c.pendingMemoryToOpen == nil)

        c.evaluateEligibility(memoriesCount: 0, ticketsCount: 0)
        await c.start()
        let memoryB = Memory(
            id: UUID(), userId: UUID(),
            name: "m2", colorFamily: "sky", emoji: nil,
            createdAt: .now, updatedAt: .now
        )
        c.donateMemoryCreated(memoryB)
        #expect(c.pendingMemoryToOpen?.id == memoryB.id)
    }
}
