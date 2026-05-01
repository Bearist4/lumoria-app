//
//  SharePayloadHandoffTests.swift
//  Lumoria AppTests
//

import XCTest
@testable import Lumoria_App

final class SharePayloadHandoffTests: XCTestCase {

    func testRoundTripJSON() throws {
        let payload = SharePayload(
            text: "UA 1471 SFO → JFK",
            image: Data("png-bytes".utf8),
            sourceURL: URL(string: "https://example.com")
        )
        var flight = SharePlaneFields()
        flight.flightNumber = "UA 1471"
        flight.originCode = "SFO"
        flight.destinationCode = "JFK"

        let result = ShareImportResult(
            classification: ShareClassification(
                category: "plane", confidence: 0.85, signals: ["regex:iata-pair"]
            ),
            flight: flight,
            event: nil,
            payload: payload
        )

        let data = try SharePayloadHandoff.encode(result)
        let decoded = try SharePayloadHandoff.decode(data)
        XCTAssertEqual(decoded, result)
    }
}
