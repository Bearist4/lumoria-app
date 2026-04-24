//
//  AnalyticsEventTests.swift
//  Lumoria AppTests
//
//  Shape tests for AnalyticsEvent. Confirms a representative sample of
//  events emit the right Title-Case name and snake_case property keys,
//  and never leak PII (email, raw tokens, raw UUIDs) into the wire format.
//

import Foundation
import Testing
@testable import Lumoria_App

@Suite("AnalyticsEvent")
struct AnalyticsEventTests {

    @Test("ticketCreated has the right name and core properties")
    func ticketCreatedShape() {
        let event = AnalyticsEvent.ticketCreated(
            category: .plane,
            template: .afterglow,
            orientation: .horizontal,
            styleId: "afterglow.default",
            fieldFillCount: 8,
            hasOriginLocation: true,
            hasDestinationLocation: true,
            ticketsLifetime: 5,
            source: .gallery
        )
        #expect(event.name == "Ticket Created")
        let props = event.properties
        #expect(props["ticket_category"] as? String == "plane")
        #expect(props["ticket_template"] as? String == "afterglow")
        #expect(props["ticket_orientation"] as? String == "horizontal")
        #expect(props["style_id"] as? String == "afterglow.default")
        #expect(props["field_fill_count"] as? Int == 8)
        #expect(props["has_origin_location"] as? Bool == true)
        #expect(props["tickets_lifetime"] as? Int == 5)
        #expect(props["source"] as? String == "gallery")
    }

    @Test("loginSucceeded carries email domain but never email")
    func loginSucceededShape() {
        let event = AnalyticsEvent.loginSucceeded(emailDomain: "gmail.com", wasFromInvite: false)
        #expect(event.name == "Login Succeeded")
        #expect(event.properties["email_domain"] as? String == "gmail.com")
        #expect(event.properties["was_from_invite"] as? Bool == false)
        #expect(event.properties["email"] == nil)
    }

    @Test("inviteShared uses token hash not raw token")
    func inviteSharedShape() {
        let event = AnalyticsEvent.inviteShared(
            channel: .system_share,
            inviteTokenHash: "abc0123456789def"
        )
        #expect(event.name == "Invite Shared")
        #expect(event.properties["channel"] as? String == "system_share")
        #expect(event.properties["invite_token_hash"] as? String == "abc0123456789def")
        #expect(event.properties["invite_token"] == nil)
    }

    @Test("ticketExported for social formats emits social_ destination keys")
    func ticketExportedSocialShape() {
        let event = AnalyticsEvent.ticketExported(
            destination: .social_story,
            resolution: nil, crop: nil, format: nil,
            includeBackground: nil, includeWatermark: nil,
            durationMs: 240
        )
        #expect(event.name == "Ticket Exported")
        let props = event.properties
        #expect(props["export_destination"] as? String == "social_story")
        #expect(props["duration_ms"] as? Int == 240)
        #expect(props["export_resolution"] == nil)
        #expect(props["export_format"] == nil)
    }

    @Test("onboardingShown has the right name and empty props")
    func onboardingShownShape() {
        let event = AnalyticsEvent.onboardingShown
        #expect(event.name == "Onboarding Shown")
        #expect(event.properties.isEmpty)
    }

    @Test("onboardingStarted has the right name")
    func onboardingStartedShape() {
        let event = AnalyticsEvent.onboardingStarted
        #expect(event.name == "Onboarding Started")
        #expect(event.properties.isEmpty)
    }

    @Test("onboardingLeft carries the step")
    func onboardingLeftShape() {
        let event = AnalyticsEvent.onboardingLeft(atStep: .welcome)
        #expect(event.name == "Onboarding Left")
        #expect(event.properties["at_step"] as? String == "welcome")
    }

    @Test("onboardingStepCompleted carries the step")
    func onboardingStepCompletedShape() {
        let event = AnalyticsEvent.onboardingStepCompleted(step: .createMemory)
        #expect(event.name == "Onboarding Step Completed")
        #expect(event.properties["step"] as? String == "create_memory")
    }

    @Test("onboardingResumed + declined events")
    func onboardingResumeEvents() {
        #expect(AnalyticsEvent.onboardingResumed.name == "Onboarding Resumed")
        #expect(AnalyticsEvent.onboardingDeclinedResume.name == "Onboarding Declined Resume")
        #expect(AnalyticsEvent.onboardingResumed.properties.isEmpty)
    }

    @Test("onboardingCompleted carries duration")
    func onboardingCompletedShape() {
        let event = AnalyticsEvent.onboardingCompleted(durationSeconds: 42)
        #expect(event.name == "Onboarding Completed")
        #expect(event.properties["duration_seconds"] as? Int == 42)
    }

    @Test("onboardingReplayed has the right name")
    func onboardingReplayedShape() {
        let event = AnalyticsEvent.onboardingReplayed
        #expect(event.name == "Onboarding Replayed")
        #expect(event.properties.isEmpty)
    }
}
