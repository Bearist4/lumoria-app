//
//  ShareConcertExtractorTests.swift
//  Lumoria AppTests
//

import XCTest
@testable import Lumoria_App

final class ShareConcertExtractorTests: XCTestCase {

    func testExtractsTaylorSwiftEras() {
        let text = """
        Your Ticketmaster order is confirmed.
        Taylor Swift — The Eras Tour
        Stade de France, Saint-Denis
        June 7, 2026 · Doors 6:00 PM · Show 7:30 PM
        Section 134, Row 22, Seat 14
        Order #: 18-12345/PAR
        """
        let result = ShareConcertExtractor.extract(text: text)
        XCTAssertEqual(result.artist, "Taylor Swift")
        XCTAssertEqual(result.tourName, "The Eras Tour")
        XCTAssertTrue(result.venue.contains("Stade de France"))
        XCTAssertEqual(result.ticketNumber, "18-12345/PAR")
    }

    func testExtractsCureAtO2() {
        let text = """
        AXS — Order confirmation
        The Cure · Live at the O2 Arena
        Doors open 7:00 PM
        Section 101, Row F, Seat 22
        Order #ABC987
        """
        let result = ShareConcertExtractor.extract(text: text)
        XCTAssertEqual(result.artist, "The Cure")
        XCTAssertTrue(result.venue.contains("O2 Arena"))
        XCTAssertEqual(result.ticketNumber, "ABC987")
    }

    func testReturnsMinimalForBareText() {
        // extract is permissive — the classifier is the real gate
        // upstream. For text the classifier would never approve, the
        // extractor still returns a struct, but the high-signal
        // fields (venue / ticket number / date) stay empty.
        let result = ShareConcertExtractor.extract(text: "Hello world")
        XCTAssertEqual(result.venue, "")
        XCTAssertEqual(result.ticketNumber, "")
        XCTAssertNil(result.date)
    }
}
