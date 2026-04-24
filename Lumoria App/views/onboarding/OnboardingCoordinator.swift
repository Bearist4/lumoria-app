//
//  OnboardingCoordinator.swift
//  Lumoria App
//
//  State machine for the first-run tutorial. Hydrates from public.profiles
//  via ProfileService on auth, exposes @Published UI flags, and a
//  currentStep enum that host views match against via .onboardingOverlay(step:).
//  All writes are optimistic locally and fire-and-forget to Supabase.
//

import Combine
import Foundation
import SwiftUI

enum ExportVariant: String, Sendable {
    case export
    case addToMemory
}

@MainActor
final class OnboardingCoordinator: ObservableObject {

    // MARK: - Persisted (server-backed)

    @Published private(set) var showOnboarding: Bool = false
    @Published private(set) var currentStep: OnboardingStep = .done

    // MARK: - Transient UI state

    @Published var showWelcome: Bool = false
    @Published var showResume: Bool = false
    @Published var showEndCover: Bool = false
    @Published var showLeaveAlert: Bool = false
    @Published var exportOrAddChoice: ExportVariant?
    /// Set at .pickTemplate advance — whether the chosen template has style
    /// variants. Consulted at .fillInfo advance to pick the next step.
    @Published var pendingStyleStep: Bool = false

    // MARK: - Analytics timing

    private var startedAt: Date?

    // MARK: - Deps

    private let service: ProfileServicing

    init(service: ProfileServicing = ProfileService()) {
        self.service = service
    }

    // MARK: - Hydration

    func loadOnAuth() async {
        do {
            let p = try await service.fetch()
            self.showOnboarding = p.showOnboarding
            self.currentStep    = p.onboardingStep
        } catch ProfileServiceError.notFound {
            self.showOnboarding = true
            self.currentStep    = .welcome
        } catch {
            print("[OnboardingCoordinator] loadOnAuth failed:", error)
            self.showOnboarding = false
            self.currentStep    = .done
        }
    }

    // MARK: - Entry presentation

    func maybePresentEntry() {
        guard showOnboarding else { return }
        switch currentStep {
        case .welcome:
            showWelcome = true
            Analytics.track(.onboardingShown)
        case .done:
            break
        default:
            showResume = true
        }
    }

    // MARK: - User actions

    func startTutorial() async {
        startedAt = Date()
        showWelcome = false
        Analytics.track(.onboardingStarted)
        await write(step: .createMemory)
    }

    func dismissWelcomeSilently() async {
        showWelcome = false
        Analytics.track(.onboardingLeft(atStep: .welcome))
        await writeShow(false)
        await write(step: .done)
    }

    func resume() async {
        showResume = false
        startedAt = Date()
        Analytics.track(.onboardingResumed)
    }

    func declineResume() async {
        showResume = false
        Analytics.track(.onboardingDeclinedResume)
        Analytics.track(.onboardingLeft(atStep: prop(for: currentStep)))
        await writeShow(false)
        await write(step: .done)
    }

    func confirmLeaveTutorial() async {
        let left = currentStep
        showLeaveAlert = false
        Analytics.track(.onboardingLeft(atStep: prop(for: left)))
        await writeShow(false)
        await write(step: .done)
    }

    /// Linear advance. Caller provides the step they expect to be on so a
    /// stale or duplicate call from a re-entered view is a no-op.
    func advance(from expected: OnboardingStep) async {
        guard currentStep == expected else { return }
        Analytics.track(.onboardingStepCompleted(step: prop(for: expected)))

        let next: OnboardingStep
        switch expected {
        case .welcome:            next = .createMemory
        case .createMemory:       next = .memoryCreated
        case .memoryCreated:      next = .enterMemory
        case .enterMemory:        next = .pickCategory
        case .pickCategory:       next = .pickTemplate
        case .pickTemplate:       next = .fillInfo
        case .fillInfo:           next = pendingStyleStep ? .pickStyle : .allDone
        case .pickStyle:          next = .allDone
        case .allDone:            next = .exportOrAddMemory
        case .exportOrAddMemory:  next = .endCover
        case .endCover:           next = .done
        case .done:               return
        }
        await write(step: next)
    }

    func chose(_ variant: ExportVariant) async {
        exportOrAddChoice = variant
        await advance(from: .allDone)
    }

    func finishAtEndCover() async {
        showEndCover = false
        let duration = startedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
        Analytics.track(.onboardingCompleted(durationSeconds: duration))
        await writeShow(false)
        await write(step: .done)
    }

    // MARK: - Settings replay

    func resetForReplay() async {
        Analytics.track(.onboardingReplayed)
        do {
            try await service.replay()
            showOnboarding    = true
            currentStep       = .welcome
            exportOrAddChoice = nil
            pendingStyleStep  = false
            startedAt         = nil
        } catch {
            print("[OnboardingCoordinator] replay failed:", error)
        }
    }

    // MARK: - Writers

    private func write(step: OnboardingStep) async {
        currentStep = step
        if step == .endCover {
            showEndCover = true
        }
        do {
            try await service.setStep(step)
        } catch {
            print("[OnboardingCoordinator] setStep failed:", error)
        }
    }

    private func writeShow(_ value: Bool) async {
        showOnboarding = value
        do {
            try await service.setShowOnboarding(value)
        } catch {
            print("[OnboardingCoordinator] setShowOnboarding failed:", error)
        }
    }

    // MARK: - Legacy compat shims (removed in Tasks 9–16 as call sites migrate)

    /// Still read by CollectionsView / ContentView. Always nil under the new
    /// flow; removed when those views are rewritten.
    @Published var pendingMemoryToOpen: Memory? = nil

    /// Replaced by `maybePresentEntry()` (called via a 3s timer in
    /// ContentView). Kept as a no-op until Task 10.
    func evaluateEligibility(memoriesCount: Int, ticketsCount: Int) { }

    /// Replaced by `advance(from: .createMemory)` wired in CollectionsStore
    /// in Task 11.
    func donateMemoryCreated(_ memory: Memory) { }

    /// Replaced by step-specific advances in Task 16 (allDone + chose).
    func donateTicketCreated() { }
    func donateExportOpened() { }

    /// Welcome sheet still uses these two until Task 9 rewrites it.
    func start() async { await startTutorial() }
    func skip() { Task { await dismissWelcomeSilently() } }

    /// Settings replay row still calls this until Task 18.
    func reset() async { await resetForReplay() }

    // MARK: - Step → prop

    private func prop(for step: OnboardingStep) -> OnboardingStepProp {
        switch step {
        case .welcome:            return .welcome
        case .createMemory:       return .createMemory
        case .memoryCreated:      return .memoryCreated
        case .enterMemory:        return .enterMemory
        case .pickCategory:       return .pickCategory
        case .pickTemplate:       return .pickTemplate
        case .fillInfo:           return .fillInfo
        case .pickStyle:          return .pickStyle
        case .allDone:            return .allDone
        case .exportOrAddMemory:  return .exportOrAddMemory
        case .endCover:           return .endCover
        case .done:               return .done
        }
    }
}
