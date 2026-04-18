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
            ticketsLifetime: 5
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
}
