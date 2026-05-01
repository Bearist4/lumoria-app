//
//  ShareImportTranslatorTests.swift
//  Lumoria AppTests
//

import XCTest
@testable import Lumoria_App

final class ShareImportTranslatorTests: XCTestCase {

    func testTranslatesPlaneCategoryString() {
        XCTAssertEqual(ShareImportTranslator.category(from: "plane"), .plane)
        XCTAssertEqual(ShareImportTranslator.category(from: "concert"), .concert)
        XCTAssertNil(ShareImportTranslator.category(from: nil))
        XCTAssertNil(ShareImportTranslator.category(from: "unknown"))
    }

    func testTranslatesPlaneFields() {
        var fields = SharePlaneFields()
        fields.flightNumber = "UA 1471"
        fields.originCode = "SFO"
        fields.destinationCode = "JFK"
        fields.gate = "B22"
        fields.seat = "14C"
        fields.terminal = "3"
        let date = Date(timeIntervalSince1970: 1_715_677_800)
        fields.departureDate = date

        let input = ShareImportTranslator.flightInput(from: fields)
        XCTAssertEqual(input.flightNumber, "UA 1471")
        XCTAssertEqual(input.originCode, "SFO")
        XCTAssertEqual(input.destinationCode, "JFK")
        XCTAssertEqual(input.gate, "B22")
        XCTAssertEqual(input.seat, "14C")
        XCTAssertEqual(input.terminal, "3")
        XCTAssertEqual(input.departureDate, date)
        XCTAssertEqual(input.departureTime, date)
    }

    func testTranslatesConcertFields() {
        var fields = ShareConcertFields()
        fields.artist = "Taylor Swift"
        fields.tourName = "The Eras Tour"
        fields.venue = "Stade de France"
        fields.ticketNumber = "18-12345/PAR"
        let date = Date(timeIntervalSince1970: 1_717_761_600)
        fields.date = date
        fields.showTime = date

        let input = ShareImportTranslator.eventInput(from: fields)
        XCTAssertEqual(input.artist, "Taylor Swift")
        XCTAssertEqual(input.tourName, "The Eras Tour")
        XCTAssertEqual(input.venue, "Stade de France")
        XCTAssertEqual(input.ticketNumber, "18-12345/PAR")
        XCTAssertEqual(input.date, date)
        XCTAssertEqual(input.showTime, date)
    }
}
