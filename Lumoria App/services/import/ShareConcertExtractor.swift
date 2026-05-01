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

        if let venue = matchCapture(text, pattern: venuePrefixPattern) {
            fields.venue = venue.trimmingCharacters(in: .whitespaces)
        } else if let venue = matchCapture(text, pattern: venueAtPattern) {
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

    /// Phrases that mark the end of vendor preamble — content
    /// (artist + tour) follows. Adding entries here when new
    /// vendors ship is the cheapest way to keep header detection
    /// accurate without rewriting the heuristic.
    private static let bannerPhrases: [String] = [
        "bestellbestätigung",
        "order details",
        "your ticketmaster order is confirmed",
        "ticketmaster order is confirmed",
        "axs — order confirmation",
        "axs - order confirmation",
        "your booking is confirmed",
    ]

    private static func headerLine(in text: String) -> String? {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Banner-based start: skip everything up to and including
        // the strongest content marker we recognize. Falls back to
        // line 0 when no banner is present.
        var startIdx = 0
        for (idx, line) in lines.enumerated() {
            let lower = line.lowercased()
            if bannerPhrases.contains(where: { lower.contains($0) }) {
                startIdx = idx + 1
                break
            }
        }

        for line in lines[startIdx...] {
            if isLikelyHeader(line) { return line }
        }
        return nil
    }

    /// Filters out greeting / vendor / label / numeric lines that
    /// can never be the artist+tour header. Errs toward inclusion —
    /// a too-permissive header gets corrected by the user; a too-
    /// strict one drops valid input on the floor.
    private static func isLikelyHeader(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 4 { return false }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("your ") { return false }
        if lower.hasPrefix("hello ") || lower.hasPrefix("hello,") { return false }
        if lower.hasPrefix("hallo ") || lower.hasPrefix("hallo,") { return false }
        if lower.hasPrefix("danke") || lower.hasPrefix("thanks") { return false }
        if lower == "du bist dabei" { return false }
        if lower.hasSuffix(":") { return false }
        if lower == "paypal" { return false }
        if lower.hasPrefix("deine bestellung") { return false }
        if lower.contains("ticketmaster") && lower.contains("bestellung") { return false }
        if lower.contains("ticketmaster") && lower.contains("confirm") { return false }
        if lower.contains("axs") && lower.contains("confirm") { return false }
        if lower.contains("oeticket") && lower.contains("order") { return false }
        return true
    }

    private static func splitHeader(_ header: String) -> (artist: String, tour: String) {
        // `: ` (colon + space) is added so Ticketmaster-style
        // headers like "Madison Beer: the locket tour" split
        // cleanly. The trailing space matters — bare `:` would
        // false-positive on label lines like "Payment:" if those
        // ever made it past the header filter.
        for sep in [" — ", " – ", " - ", " · ", ": "] {
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

    /// Captures the venue when the email uses an explicit "Venue:" /
    /// "Veranstaltungsort:" / "Location:" / "Lieu:" label. Highest-
    /// signal venue extractor — vendors that label fields tend to
    /// label them consistently across confirmation templates.
    private static let venuePrefixPattern = try! NSRegularExpression(
        pattern: #"(?i)(?:Venue|Veranstaltungsort|Location|Lieu)\s*:\s*([^,\n]+?)(?:,|\n|$)"#
    )

    /// Captures venue after "Live at" / "Live at the". Bare-"at" was
    /// removed — it false-positives inside "Seat", "Stadium", etc.
    private static let venueAtPattern = try! NSRegularExpression(
        pattern: #"(?i)\bLive\s+at(?:\s+the)?\s+([^,\n]+?)(?:,|\n|$)"#
    )

    /// Picks the first line after the artist header that looks like
    /// a venue. Walks past date/time/numeric lines (so layouts like
    /// "<artist>\n<date>\n<venue>" still resolve correctly), but
    /// bails after a few attempts so the heuristic doesn't pull a
    /// totally unrelated line from the bottom of the email.
    private static func venueLineHeuristic(in text: String, after header: String) -> String? {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let headerIdx = lines.firstIndex(of: header) else { return nil }
        var idx = lines.index(after: headerIdx)
        var attempts = 0
        while idx < lines.endIndex && attempts < 4 {
            let candidate = lines[idx]
            attempts += 1
            idx = lines.index(after: idx)
            // Reject pure-numeric / date / time lines.
            if candidate.range(of: #"\d"#, options: .regularExpression) != nil { continue }
            // Reject label lines like "Payment:" or "Stehplatz".
            if candidate.hasSuffix(":") { continue }
            // Reject single short tokens that are unlikely to be a venue.
            if candidate.count < 4 { continue }
            if let commaRange = candidate.range(of: ",") {
                return String(candidate[..<commaRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
            }
            return candidate
        }
        return nil
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
