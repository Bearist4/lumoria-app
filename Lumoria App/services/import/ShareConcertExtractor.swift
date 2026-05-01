//
//  ShareConcertExtractor.swift
//  Lumoria App
//
//  Pulls ShareConcertFields out of concert-confirmation text using
//  regex + NLTagger for proper-noun extraction. Header-style layouts
//  ("Artist — Tour Name") cover most ticketing vendor templates.
//

import Foundation
import NaturalLanguage

enum ShareConcertExtractor {

    static func extract(text: String) -> ShareConcertFields {
        var fields = ShareConcertFields()

        let header = headerLine(in: text)
        if let header {
            let parts = splitHeader(header)
            fields.artist = parts.artist
            fields.tourName = parts.tour
        }

        if let venue = matchCapture(text, pattern: venuePattern) {
            fields.venue = venue.trimmingCharacters(in: .whitespaces)
        } else if let header, let venue = venueLineHeuristic(in: text, after: header) {
            fields.venue = venue
        } else if let venue = nlVenueGuess(text) {
            fields.venue = venue
        }

        if let order = matchCapture(text, pattern: orderNumberPattern) {
            fields.ticketNumber = order.trimmingCharacters(in: .whitespaces)
        }

        if let date = firstDate(in: text) {
            fields.date = date
            fields.showTime = date
        }
        if let doors = matchCapture(text, pattern: doorsPattern),
           let date = fields.date,
           let doorsDate = combineTime(doors, with: date) {
            fields.doorsTime = doorsDate
        }

        return fields
    }

    // MARK: - Header

    private static func headerLine(in text: String) -> String? {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for line in lines {
            let lower = line.lowercased()
            if lower.contains("ticketmaster") && lower.contains("confirm") { continue }
            if lower.contains("axs") && lower.contains("confirm") { continue }
            if lower.contains("order") && lower.contains("confirm") { continue }
            if lower.hasPrefix("your ") { continue }
            return line
        }
        return nil
    }

    private static func splitHeader(_ header: String) -> (artist: String, tour: String) {
        for sep in [" — ", " – ", " - ", " · "] {
            if let range = header.range(of: sep) {
                let artist = String(header[..<range.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let tour = String(header[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                if tour.lowercased().hasPrefix("live at ") {
                    return (artist, "")
                }
                return (artist, tour)
            }
        }
        return (header, "")
    }

    // MARK: - Venue

    /// Captures venue after "Live at" / "Live at the". Bare-"at" was
    /// removed — it false-positives inside "Seat", "Stadium",
    /// "matter", etc. Venues without a "Live at" preamble fall to
    /// `venueLineHeuristic` (line right after the artist header).
    private static let venuePattern = try! NSRegularExpression(
        pattern: #"(?i)\bLive\s+at(?:\s+the)?\s+([^,\n]+?)(?:,|\n|$)"#
    )

    /// Picks the line immediately after the artist header as the
    /// venue when it doesn't look like a date/time/section line.
    /// Concert templates almost always put the venue on the line
    /// right after the artist+tour header; this catches cases that
    /// the "Live at <X>" / "at <X>" regex misses (e.g. Ticketmaster
    /// emails that use a bare "Stade de France, Saint-Denis").
    private static func venueLineHeuristic(in text: String, after header: String) -> String? {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let headerIdx = lines.firstIndex(of: header) else { return nil }
        let nextIdx = lines.index(after: headerIdx)
        guard nextIdx < lines.endIndex else { return nil }
        let candidate = lines[nextIdx]
        // Reject if the line looks like a date/time/section/order
        // line. Numeric content is the cheapest signal.
        if candidate.range(of: #"\d"#, options: .regularExpression) != nil {
            return nil
        }
        if let commaRange = candidate.range(of: ",") {
            return String(candidate[..<commaRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
        }
        return candidate
    }

    private static func nlVenueGuess(_ text: String) -> String? {
        // Gate the NLTagger fallback behind concert-context keywords.
        // Without this, NLTagger happily calls any capitalized noun a
        // place — "Hello World" would resolve to a venue.
        let lower = text.lowercased()
        let signals = [
            "doors", "concert", "tour", "live", "section", "row",
            "showtime", "show time", "venue", "stage", "arena",
            "stadium", "theater", "theatre", "hall",
        ]
        guard signals.contains(where: { lower.contains($0) }) else {
            return nil
        }
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let options: NLTagger.Options = [
            .omitWhitespace, .omitPunctuation, .joinNames,
        ]
        var longest: String = ""
        let range = text.startIndex..<text.endIndex
        tagger.enumerateTags(
            in: range,
            unit: .word,
            scheme: .nameType,
            options: options
        ) { tag, tokenRange in
            if tag == .placeName {
                let phrase = String(text[tokenRange])
                if phrase.count > longest.count { longest = phrase }
            }
            return true
        }
        return longest.isEmpty ? nil : longest
    }

    // MARK: - Order number

    /// Require at least one `#` or `:` after "Order" so the regex
    /// doesn't capture "is" out of "Your Ticketmaster order is
    /// confirmed." Capture group keeps an explicit `[A-Z0-9]` class
    /// (no `(?i)` flag) so lowercase tokens never match.
    private static let orderNumberPattern = try! NSRegularExpression(
        pattern: #"[Oo]rder\s*[#:]+\s*([A-Z0-9][A-Z0-9\-/]+)"#
    )

    // MARK: - Doors / show

    private static let doorsPattern = try! NSRegularExpression(
        pattern: #"(?i)Doors?\s*(?:open\s*at\s*)?:?\s*(\d{1,2}[:.]?\d{0,2}\s*(?:AM|PM)?)"#
    )

    private static func combineTime(_ raw: String, with anchor: Date) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let formatters: [DateFormatter] = ["h:mm a", "HH:mm", "h a"].map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            return f
        }
        for f in formatters {
            if let parsed = f.date(from: trimmed) {
                let cal = Calendar.current
                let timeParts = cal.dateComponents([.hour, .minute], from: parsed)
                var anchorParts = cal.dateComponents([.year, .month, .day], from: anchor)
                anchorParts.hour = timeParts.hour
                anchorParts.minute = timeParts.minute ?? 0
                return cal.date(from: anchorParts)
            }
        }
        return nil
    }

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

    // MARK: - Regex helper

    private static func matchCapture(_ text: String, pattern: NSRegularExpression) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = pattern.firstMatch(in: text, range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}
