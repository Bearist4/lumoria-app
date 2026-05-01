//
//  ShareCategoryClassifierTests.swift
//  Lumoria AppTests
//

import XCTest
@testable import Lumoria_App

final class ShareCategoryClassifierTests: XCTestCase {

    // MARK: - Plane

    func testClassifiesUnitedConfirmationAsPlane() {
        let text = """
        Your United flight is confirmed.
        Confirmation: ABC123
        UA 1471 — SFO → JFK
        Departing Tue, May 14, 6:30 AM
        Boarding pass attached.
        From: receipts@united.com
        """
        let result = ShareCategoryClassifier.classify(text: text)
        XCTAssertEqual(result.category, "plane")
        XCTAssertGreaterThanOrEqual(result.confidence, 0.7)
    }

    func testClassifiesAirFranceAsPlane() {
        let text = """
        Votre carte d'embarquement
        Vol AF 1280 Paris CDG → Amsterdam AMS
        Départ 12 juin 14:25
        Porte K42 Siège 18A
        """
        let result = ShareCategoryClassifier.classify(text: text)
        XCTAssertEqual(result.category, "plane")
    }

    func testClassifiesGenericIATATextAsPlane() {
        let text = "BA 286 LHR-SFO Gate 23 Seat 14C departure 11:45"
        let result = ShareCategoryClassifier.classify(text: text)
        XCTAssertEqual(result.category, "plane")
    }

    // MARK: - Concert

    func testClassifiesTicketmasterAsConcert() {
        let text = """
        Your Ticketmaster order is confirmed.
        Taylor Swift — The Eras Tour
        Stade de France, Saint-Denis
        June 7, 2026 · Doors 6:00 PM
        Section 134, Row 22, Seat 14
        Order #: 18-12345/PAR
        From: customer_service@ticketmaster.fr
        """
        let result = ShareCategoryClassifier.classify(text: text)
        XCTAssertEqual(result.category, "concert")
        XCTAssertGreaterThanOrEqual(result.confidence, 0.7)
    }

    func testClassifiesAXSConcertAsConcert() {
        let text = """
        AXS — Order confirmation
        The Cure · Live at the O2 Arena
        Doors open 7:00 PM
        Section 101, Row F, Seat 22
        """
        let result = ShareCategoryClassifier.classify(text: text)
        XCTAssertEqual(result.category, "concert")
    }

    // MARK: - Negative

    func testReturnsNilCategoryForUnrelatedText() {
        let text = """
        Hi team,
        Quick reminder that the design review is at 3pm today.
        Thanks!
        """
        let result = ShareCategoryClassifier.classify(text: text)
        XCTAssertNil(result.category)
        XCTAssertLessThan(result.confidence, 0.7)
    }

    func testReturnsNilForEmptyText() {
        let result = ShareCategoryClassifier.classify(text: "")
        XCTAssertNil(result.category)
        XCTAssertEqual(result.confidence, 0.0)
    }
}
