//
//  NewTicketFunnelAutofillTests.swift
//  Lumoria AppTests
//
//  Each test populates the per-template required fields so canAdvance
//  returns true and advance() actually runs applyAestheticDefaults().
//  Required values are arbitrary (we never assert on them) — only the
//  blank optional fields under test matter.
//

import Foundation
import Testing
@testable import Lumoria_App

// MARK: - Helpers

@MainActor
private func makePlaneFunnel(_ template: TicketTemplateKind) -> NewTicketFunnel {
    let funnel = NewTicketFunnel()
    funnel.template = template
    funnel.step = .form
    // FlightFormInput.isMinimallyValid: airline, flightNumber, origin, destination.
    funnel.form.airline = "Air Test"
    funnel.form.flightNumber = "AT 123"
    funnel.form.originCode = "AAA"
    funnel.form.destinationCode = "BBB"
    return funnel
}

@MainActor
private func makeTrainFunnel(_ template: TicketTemplateKind) -> NewTicketFunnel {
    let funnel = NewTicketFunnel()
    funnel.template = template
    funnel.step = .form
    funnel.trainForm.originCity = "City A"
    funnel.trainForm.destinationCity = "City B"
    // Different templates need different extras to validate.
    switch template {
    case .express, .post, .glow:
        funnel.trainForm.trainType = "Test"
        funnel.trainForm.trainNumber = "001"
    case .orient:
        funnel.trainForm.company = "Test Rail"
    case .night:
        funnel.trainForm.company = "Test Rail"
        funnel.trainForm.trainType = "Sleeper"
        funnel.trainForm.trainNumber = "001"
    default:
        break
    }
    return funnel
}

// MARK: - Plane

@MainActor
@Test func autofill_planeBasic_fillsGateAndSeat_whenBlank() async throws {
    let funnel = makePlaneFunnel(.afterglow)
    funnel.form.gate = ""
    funnel.form.seat = ""

    funnel.advance()

    #expect(!funnel.form.gate.isEmpty)
    #expect(!funnel.form.seat.isEmpty)
    #expect(funnel.autoFilledFields.contains("Gate"))
    #expect(funnel.autoFilledFields.contains("Seat"))
}
