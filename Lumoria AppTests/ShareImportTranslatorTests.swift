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

    func testDoorsDefaultsTo45MinutesBeforeShowWhenMissing() {
        var fields = ShareConcertFields()
        fields.artist = "Madison Beer"
        fields.venue = "Marx Halle"
        let date = Date(timeIntervalSince1970: 1_778_731_200) // 2026-05-13
        fields.date = date
        fields.showTime = date.addingTimeInterval(20 * 3600) // 20:00
        // Intentionally omit doorsTime.

        let input = ShareImportTranslator.eventInput(from: fields)
        let expectedDoors = fields.showTime!.addingTimeInterval(-45 * 60)
        XCTAssertEqual(input.doorsTime, expectedDoors)
        XCTAssertEqual(input.showTime, fields.showTime)
    }

    func testDoorsRespectsExtractedValueWhenPresent() {
        var fields = ShareConcertFields()
        let date = Date(timeIntervalSince1970: 1_778_731_200)
        fields.date = date
        fields.doorsTime = date.addingTimeInterval(18 * 3600) // 18:00 (2h gap)
        fields.showTime = date.addingTimeInterval(20 * 3600) // 20:00

        let input = ShareImportTranslator.eventInput(from: fields)
        XCTAssertEqual(input.doorsTime, fields.doorsTime,
                       "Explicit doors time should not be overridden by the 45-min fallback")
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
