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
        Text("Create a memory")
    }
    var message: Text? {
        Text("A trip, a show, anything. Give it a name.")
    }
    var rules: [Rule] {
        #Rule(OnboardingEvents.onboardingStarted) { $0.donations.count > 0 }
        #Rule(OnboardingEvents.firstMemoryCreated) { $0.donations.count == 0 }
    }
}

// MARK: - Ticket tip

struct TicketTip: Tip {
    var title: Text {
        Text("Add a ticket")
    }
    var message: Text? {
        Text("Pick a style. Fill in the details.")
    }
    var rules: [Rule] {
        #Rule(OnboardingEvents.firstMemoryCreated) { $0.donations.count > 0 }
        #Rule(OnboardingEvents.firstTicketCreated) { $0.donations.count == 0 }
    }
}

// MARK: - Export tip

struct ExportTip: Tip {
    var title: Text {
        Text("Share it")
    }
    var message: Text? {
        Text("Post it, send it, or save it to camera roll.")
    }
    var rules: [Rule] {
        #Rule(OnboardingEvents.firstTicketCreated) { $0.donations.count > 0 }
        #Rule(OnboardingEvents.onboardingComplete) { $0.donations.count == 0 }
    }
}
