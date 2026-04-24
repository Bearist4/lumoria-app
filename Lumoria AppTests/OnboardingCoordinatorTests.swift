//
//  OnboardingCoordinatorTests.swift
//  Lumoria AppTests
//
//  State-transition tests for the onboarding coordinator. Uses a mock
//  ProfileServicing so no network / Supabase calls fire.
//

import Foundation
import Testing
@testable import Lumoria_App

// MARK: - Mock service

final class MockProfileService: ProfileServicing, @unchecked Sendable {
    var storedProfile: Profile?
    var fetchError: Error?
    var writtenSteps: [OnboardingStep] = []
    var writtenShowFlags: [Bool] = []
    var replayCalls = 0

    init(profile: Profile? = nil) { self.storedProfile = profile }

    func fetch() async throws -> Profile {
        if let err = fetchError { throw err }
        guard let p = storedProfile else { throw ProfileServiceError.notFound }
        return p
    }
    func setStep(_ step: OnboardingStep) async throws {
        writtenSteps.append(step)
        storedProfile?.onboardingStep = step
    }
    func setShowOnboarding(_ value: Bool) async throws {
        writtenShowFlags.append(value)
        storedProfile?.showOnboarding = value
    }
    func replay() async throws {
        replayCalls += 1
        if var p = storedProfile {
            p.showOnboarding = true
            p.onboardingStep = .welcome
            storedProfile = p
        }
    }
}

@MainActor
@Suite("OnboardingCoordinator")
struct OnboardingCoordinatorTests {

    private func makeProfile(show: Bool, step: OnboardingStep) -> Profile {
        Profile(userId: UUID(), showOnboarding: show, onboardingStep: step)
    }

    @Test
    func loadOnAuth_hydratesState() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .welcome))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        #expect(coord.showOnboarding == true)
        #expect(coord.currentStep == .welcome)
    }

    @Test
    func loadOnAuth_notFound_defaultsToFreshTutorial() async throws {
        let service = MockProfileService(profile: nil)
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        #expect(coord.showOnboarding == true)
        #expect(coord.currentStep == .welcome)
    }

    @Test
    func maybePresentEntry_showsWelcomeAtStepWelcome() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .welcome))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        coord.maybePresentEntry()
        #expect(coord.showWelcome == true)
        #expect(coord.showResume == false)
    }

    @Test
    func maybePresentEntry_showsResumeWhenStepBeyondWelcome() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .pickCategory))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        coord.maybePresentEntry()
        #expect(coord.showResume == true)
        #expect(coord.showWelcome == false)
    }

    @Test
    func maybePresentEntry_noSheetWhenOnboardingOff() async throws {
        let service = MockProfileService(profile: makeProfile(show: false, step: .done))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        coord.maybePresentEntry()
        #expect(coord.showWelcome == false)
        #expect(coord.showResume == false)
    }

    @Test
    func startTutorial_advancesToCreateMemory() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .welcome))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.startTutorial()
        #expect(coord.currentStep == .createMemory)
        #expect(coord.showWelcome == false)
        #expect(service.writtenSteps == [.createMemory])
    }

    @Test
    func dismissWelcomeSilently_turnsOffFlag() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .welcome))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.dismissWelcomeSilently()
        #expect(coord.showOnboarding == false)
        #expect(coord.currentStep == .done)
        #expect(service.writtenShowFlags == [false])
        #expect(service.writtenSteps == [.done])
    }

    @Test
    func advance_fromMatchingStepTransitions() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .createMemory))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.advance(from: .createMemory)
        #expect(coord.currentStep == .memoryCreated)
    }

    @Test
    func advance_fromMismatchedStepIsNoOp() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .pickCategory))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.advance(from: .createMemory)
        #expect(coord.currentStep == .pickCategory)
        #expect(service.writtenSteps.isEmpty)
    }

    @Test
    func advance_fromFillInfoSkipsPickStyleWhenNoVariants() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .fillInfo))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        coord.pendingStyleStep = false
        await coord.advance(from: .fillInfo)
        #expect(coord.currentStep == .allDone)
    }

    @Test
    func advance_fromFillInfoIncludesPickStyleWhenVariantsExist() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .fillInfo))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        coord.pendingStyleStep = true
        await coord.advance(from: .fillInfo)
        #expect(coord.currentStep == .pickStyle)
    }

    @Test
    func chose_recordsVariantAndAdvances() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .allDone))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.chose(.export)
        #expect(coord.currentStep == .exportOrAddMemory)
        #expect(coord.exportOrAddChoice == .export)
    }

    @Test
    func confirmLeaveTutorial_setsFlagFalseAndStepDone() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .pickCategory))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.confirmLeaveTutorial()
        #expect(coord.showOnboarding == false)
        #expect(coord.currentStep == .done)
    }

    @Test
    func resetForReplay_rewinds() async throws {
        let service = MockProfileService(profile: makeProfile(show: false, step: .done))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.resetForReplay()
        #expect(coord.showOnboarding == true)
        #expect(coord.currentStep == .welcome)
        #expect(service.replayCalls == 1)
    }

    @Test
    func finishAtEndCover_completes() async throws {
        let service = MockProfileService(profile: makeProfile(show: true, step: .endCover))
        let coord = OnboardingCoordinator(service: service)
        await coord.loadOnAuth()
        await coord.finishAtEndCover()
        #expect(coord.showOnboarding == false)
        #expect(coord.currentStep == .done)
    }
}
