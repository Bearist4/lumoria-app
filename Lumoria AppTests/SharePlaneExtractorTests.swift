//
//  SharePlaneExtractorTests.swift
//  Lumoria AppTests
//

import XCTest
@testable import Lumoria_App

final class SharePlaneExtractorTests: XCTestCase {

    func testExtractsUnitedFields() {
        let text = """
        Your United flight is confirmed.
        Confirmation: ABC123
        UA 1471 — SFO → JFK
        Departing Tue, May 14, 6:30 AM
        Gate B22 · Seat 14C · Terminal 3
        """
        let result = SharePlaneExtractor.extract(text: text)
        XCTAssertEqual(result.flightNumber, "UA 1471")
        XCTAssertEqual(result.originCode, "SFO")
        XCTAssertEqual(result.destinationCode, "JFK")
        XCTAssertEqual(result.gate, "B22")
        XCTAssertEqual(result.seat, "14C")
        XCTAssertEqual(result.terminal, "3")
    }

    func testExtractsAirFranceFields() {
        let text = """
        Air France
        AF 1280 CDG → AMS
        12 juin 14:25
        Porte K42 Siège 18A
        """
        let result = SharePlaneExtractor.extract(text: text)
        XCTAssertEqual(result.flightNumber, "AF 1280")
        XCTAssertEqual(result.originCode, "CDG")
        XCTAssertEqual(result.destinationCode, "AMS")
        XCTAssertEqual(result.gate, "K42")
        XCTAssertEqual(result.seat, "18A")
    }

    func testExtractsBareIATAPairWithDash() {
        let text = "BA 286 LHR-SFO Gate 23 Seat 14C"
        let result = SharePlaneExtractor.extract(text: text)
        XCTAssertEqual(result.flightNumber, "BA 286")
        XCTAssertEqual(result.originCode, "LHR")
        XCTAssertEqual(result.destinationCode, "SFO")
        XCTAssertEqual(result.gate, "23")
        XCTAssertEqual(result.seat, "14C")
    }

    func testReturnsEmptyWhenNothingMatches() {
        let result = SharePlaneExtractor.extract(text: "Hello world")
        XCTAssertEqual(result.flightNumber, "")
        XCTAssertEqual(result.originCode, "")
        XCTAssertEqual(result.destinationCode, "")
    }
}
