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

/// One-shot route emitted by `resume()` so the host can navigate to the
/// screen the user left off on. Cleared by the host after consumption.
enum OnboardingResumeRoute: Sendable, Equatable {
    /// Push the first memory's detail view (used for `.enterMemory`).
    case openFirstMemory
    /// Present the new-ticket funnel full-screen (used for any
    /// funnel-stage step from `.pickCategory` through `.exportOrAddMemory`).
    case openNewTicketFunnel
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
    /// Set by `resume()` so the host (MemoriesView) can route the user
    /// back to where they left off. Host clears it after consuming.
    @Published var pendingResumeRoute: OnboardingResumeRoute?

    // MARK: - Analytics timing

    private var startedAt: Date?

    // MARK: - Deps

    private let service: ProfileServicing

    nonisolated init(service: ProfileServicing = ProfileService()) {
        self.service = service
    }

    /// True while the tutorial is parked on a step whose overlay sits on
    /// a tabbed screen — we hide the tab bar so it doesn't render above
    /// the dim layer (the tab bar is a sibling of the tab content, not
    /// a child, so per-screen overlays can't cover it).
    var shouldHideTabBar: Bool {
        guard showOnboarding else { return false }
        switch currentStep {
        case .createMemory, .memoryCreated, .enterMemory:
            return true
        case .welcome, .pickCategory, .pickTemplate, .fillInfo,
             .pickStyle, .allDone, .exportOrAddMemory,
             .endCover, .done:
            return false
        }
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
        OnboardingFunnelDraftStore.clear()
        await writeShow(false)
        await write(step: .done)
    }

    func resume() async {
        showResume = false
        startedAt = Date()
        Analytics.track(.onboardingResumed)
        pendingResumeRoute = routeForCurrentStep()
    }

    /// Maps the persisted step to a one-shot route for the host. Memory
    /// steps stay on the Memories tab root, so they return nil. The
    /// endCover sheet auto-presents on its own via `showEndCover`.
    private func routeForCurrentStep() -> OnboardingResumeRoute? {
        switch currentStep {
        case .enterMemory:
            return .openFirstMemory
        case .pickCategory, .pickTemplate, .fillInfo,
             .pickStyle, .allDone, .exportOrAddMemory:
            return .openNewTicketFunnel
        case .welcome, .createMemory, .memoryCreated,
             .endCover, .done:
            return nil
        }
    }

    func declineResume() async {
        showResume = false
        Analytics.track(.onboardingDeclinedResume)
        Analytics.track(.onboardingLeft(atStep: prop(for: currentStep)))
        OnboardingFunnelDraftStore.clear()
        await writeShow(false)
        await write(step: .done)
    }

    func confirmLeaveTutorial() async {
        let left = currentStep
        showLeaveAlert = false
        // Also drop any in-flight entry sheets so the user actually
        // sees the dismissal — the Welcome sheet is wired to this
        // alert when the user skips from the welcome step itself.
        showWelcome = false
        showResume = false
        Analytics.track(.onboardingLeft(atStep: prop(for: left)))
        OnboardingFunnelDraftStore.clear()
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
        OnboardingFunnelDraftStore.clear()
        await writeShow(false)
        await write(step: .done)
    }

    // MARK: - Settings replay

    func resetForReplay() async {
        Analytics.track(.onboardingReplayed)
        OnboardingFunnelDraftStore.clear()
        do {
            try await service.replay()
            showOnboarding    = true
            currentStep       = .welcome
            exportOrAddChoice = nil
            pendingStyleStep  = false
            startedAt         = nil
            pendingResumeRoute = nil
            // Surface the Welcome sheet immediately. ContentView's
            // `.onChange(of: showWelcome)` flips the user back to the
            // Memories tab so the sheet appears in the right context.
            showWelcome = true
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
