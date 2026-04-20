//
//  OnboardingTips.swift
//  Lumoria App
//
//  TipKit Tip definitions + shared Tips.Event instances used by the
//  onboarding chain. OnboardingCoordinator donates to these events; each
//  Tip's rule observes them to decide whether to show.
//

import SwiftUI
import TipKit

// MARK: - Shared events

enum OnboardingEvents {
    static let onboardingStarted    = Tips.Event(id: "onboarding.started")
    static let firstMemoryCreated   = Tips.Event(id: "onboarding.firstMemoryCreated")
    static let firstTicketCreated   = Tips.Event(id: "onboarding.firstTicketCreated")
    static let onboardingComplete   = Tips.Event(id: "onboarding.complete")
}

// MARK: - Memory tip

struct MemoryTip: Tip {
    var title: Text {
        Text("onboarding.tip.memory.title")
    }
    var message: Text? {
        Text("onboarding.tip.memory.message")
    }
    var rules: [Rule] {
        #Rule(OnboardingEvents.onboardingStarted) { $0.donations.count > 0 }
        #Rule(OnboardingEvents.firstMemoryCreated) { $0.donations.count == 0 }
    }
}

// MARK: - Ticket tip

struct TicketTip: Tip {
    var title: Text {
        Text("onboarding.tip.ticket.title")
    }
    var message: Text? {
        Text("onboarding.tip.ticket.message")
    }
    var rules: [Rule] {
        #Rule(OnboardingEvents.firstMemoryCreated) { $0.donations.count > 0 }
        #Rule(OnboardingEvents.firstTicketCreated) { $0.donations.count == 0 }
    }
}

// MARK: - Export tip

struct ExportTip: Tip {
    var title: Text {
        Text("onboarding.tip.export.title")
    }
    var message: Text? {
        Text("onboarding.tip.export.message")
    }
    var rules: [Rule] {
        #Rule(OnboardingEvents.firstTicketCreated) { $0.donations.count > 0 }
        #Rule(OnboardingEvents.onboardingComplete) { $0.donations.count == 0 }
    }
}
