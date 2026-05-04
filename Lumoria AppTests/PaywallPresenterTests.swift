//
//  PaywallPresenterTests.swift
//  Lumoria AppTests
//
//  Verifies the routing matrix in Paywall.present(for:entitlement:state:):
//    - limit triggers always set state for free users (regardless of kPaymentsEnabled)
//    - non-limit triggers no-op while kPaymentsEnabled is false
//    - any trigger no-ops once the user has premium
//

import Foundation
import Testing
@testable import Lumoria_App

@MainActor
@Suite("Paywall.present routing")
struct PaywallPresenterTests {

    @Test("limit triggers always set state when user is free")
    func limitTriggerSetsState() {
        let entitlement = EntitlementStore.previewInstance(
            tier: .free,
            monetisationEnabled: true
        )
        let state = Paywall.PresentationState()

        Paywall.present(for: .memoryLimit, entitlement: entitlement, state: state)
        #expect(state.trigger == .memoryLimit)

        state.trigger = nil
        Paywall.present(for: .ticketLimit, entitlement: entitlement, state: state)
        #expect(state.trigger == .ticketLimit)
    }

    @Test("non-limit triggers no-op while kPaymentsEnabled is false")
    func nonLimitTriggerNoOpWhenPaymentsDisabled() {
        #expect(EntitlementStore.kPaymentsEnabled == false)
        let entitlement = EntitlementStore.previewInstance(
            tier: .free,
            monetisationEnabled: true
        )
        let state = Paywall.PresentationState()

        Paywall.present(for: .upgradeFromSettings, entitlement: entitlement, state: state)
        #expect(state.trigger == nil)

        Paywall.present(for: .timelineLocked, entitlement: entitlement, state: state)
        #expect(state.trigger == nil)
    }

    @Test("present is no-op when user already has premium")
    func skipsWhenPremium() {
        let entitlement = EntitlementStore.previewInstance(
            tier: .grandfathered,
            monetisationEnabled: true
        )
        let state = Paywall.PresentationState()

        Paywall.present(for: .memoryLimit, entitlement: entitlement, state: state)
        #expect(state.trigger == nil)
    }
}
