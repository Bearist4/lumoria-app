//
//  SharePlaneExtractor.swift
//  Lumoria App
//
//  Pulls SharePlaneFields out of arbitrary plane-confirmation text
//  using regex tables and NSDataDetector. Output struct is Codable
//  primitives only — the main-app translator copies it into a
//  `FlightFormInput` after the funnel applies the result.
//

import Foundation

enum SharePlaneExtractor {

    static func extract(text: String) -> SharePlaneFields {
        var fields = SharePlaneFields()

        if let flight = matchFirst(text, pattern: flightNumberPattern) {
            fields.flightNumber = flight
        }
        if let pair = matchPair(text, pattern: iataPairPattern) {
            fields.originCode = pair.0
            fields.destinationCode = pair.1
        }
        fields.gate = matchCapture(text, pattern: gatePattern) ?? ""
        fields.seat = matchCapture(text, pattern: seatPattern) ?? ""
        fields.terminal = matchCapture(text, pattern: terminalPattern) ?? ""
        if let date = firstDate(in: text) {
            fields.departureDate = date
        }
        return fields
    }

    // MARK: - Patterns

    private static let flightNumberPattern = try! NSRegularExpression(
        // Mandatory whitespace between carrier and digits — without
        // it, "ABC123" (a confirmation code) matches before "UA 1471"
        // in a typical confirmation email.
        pattern: #"\b([A-Z]{2,3})\s(\d{1,4}[A-Z]?)\b"#
    )

    private static let iataPairPattern = try! NSRegularExpression(
        pattern: #"\b([A-Z]{3})\s*(?:[→\-—]|to)\s*([A-Z]{3})\b"#
    )

    private static let gatePattern = try! NSRegularExpression(
        pattern: #"(?i)(?:Gate|Porte)[:\s]+([A-Z]?\d+[A-Z]?)"#
    )

    private static let seatPattern = try! NSRegularExpression(
        pattern: #"(?i)(?:Seat|Siège|Si.ge)[:\s]+(\d{1,3}[A-Z]?)"#
    )

    private static let terminalPattern = try! NSRegularExpression(
        pattern: #"(?i)Terminal[:\s]+([A-Z0-9]+)"#
    )

    // MARK: - Date

    private static let dateDetector: NSDataDetector? = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    private static func firstDate(in text: String) -> Date? {
        let range = NSRange(text.startIndex..., in: text)
        guard let detector = dateDetector,
              let match = detector.firstMatch(in: text, range: range) else {
            return nil
        }
        return match.date
    }

    // MARK: - Regex helpers

    private static func matchFirst(_ text: String, pattern: NSRegularExpression) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = pattern.firstMatch(in: text, range: range),
              let r = Range(match.range, in: text) else { return nil }
        return String(text[r])
    }

    private static func matchCapture(_ text: String, pattern: NSRegularExpression) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = pattern.firstMatch(in: text, range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    private static func matchPair(_ text: String, pattern: NSRegularExpression) -> (String, String)? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = pattern.firstMatch(in: text, range: range),
              match.numberOfRanges >= 3,
              let a = Range(match.range(at: 1), in: text),
              let b = Range(match.range(at: 2), in: text) else { return nil }
        return (String(text[a]), String(text[b]))
    }
}
