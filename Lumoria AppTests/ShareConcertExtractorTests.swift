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

    func testExtractsMadisonBeerTicketmaster() {
        let text = """
        Deine Bestellung bei Ticketmaster
        Du Bist Dabei
        Hallo Benjamin,
        danke für deine Bestellung!
        Deine Bestellbestätigung
        Madison Beer: the locket tour
        Mittwoch, 13. Mai 2026, 20:00 Uhr
        Marx Halle
        Stehplatz
        PK1 Stehplatz - Endpreis 79,90€
        """
        let result = ShareConcertExtractor.extract(text: text)
        XCTAssertEqual(result.artist, "Madison Beer", "got=\(result.artist)")
        // Title-cased: source text is "the locket tour" (all-lowercase),
        // extractor restores readable casing.
        XCTAssertEqual(result.tourName, "The Locket Tour", "got=\(result.tourName)")
        XCTAssertTrue(result.venue.contains("Marx Halle"), "venue=\(result.venue)")
    }

    func testExtractsEurovisionOeticket() {
        let text = """
        Your oeticket Order - Grand Final Afternoon Preview
        Payment:
        PayPal
        ORDER DETAILS
        Grand Final Afternoon Preview
        Date: Sat, 16.05.2026, 12:00
        Venue: Wiener Stadthalle Halle D, Roland-Rainer-Platz 1 / Eingang Märzpark, 1150 WIEN
        Promoter: 80:Österreichischer Rundfunk (ORF) - ESC, Hugo-Portisch-Gasse 1, 1136 Wien, Austria
        Promotion: Eurovisions Song Contest 2026
        Seats Category A, standard price
        Surname: Caillet
        First name: Benjamin
        Entrance 1. Rang Süd, Area 64 - Tor Orange, Row 3, Seat 104
        """
        let result = ShareConcertExtractor.extract(text: text)
        XCTAssertEqual(result.artist, "Grand Final Afternoon Preview", "got=\(result.artist)")
        XCTAssertTrue(result.venue.contains("Wiener Stadthalle"), "venue=\(result.venue)")
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
