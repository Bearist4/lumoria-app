//
//  ShareFoundationModelsExtractor.swift
//  LumoriaShareImport
//
//  On-device Foundation Models fallback for low-confidence
//  classifications. Runs the system language model with a
//  `@Generable` schema so the response is structured and typed.
//  Honors the project's "no paid LLM APIs" rule — this is local,
//  free, private, and never leaves the device.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

@available(iOS 26.0, *)
enum ShareFoundationModelsExtractor {

    /// Runs the on-device language model to classify + extract
    /// ticket fields. Returns nil when the model is unavailable
    /// (Apple Intelligence not enabled, device ineligible, model
    /// still downloading, or the request fails).
    static func guess(text: String) async -> ShareExtractionGuess? {
        #if canImport(FoundationModels)
        guard case .available = SystemLanguageModel.default.availability else {
            NSLog("[Lumoria] FM unavailable: %@",
                  String(describing: SystemLanguageModel.default.availability))
            return nil
        }
        let session = LanguageModelSession {
            """
            You extract ticket details from confirmation emails or \
            screenshots of confirmation emails. The text may contain \
            visual noise from OCR — logos, navigation chrome, ad banners. \
            Identify whether the ticket is for a plane or concert event, \
            then fill only the fields you can confidently extract.

            STRICT RULES:
            - "venue" must be the venue name (e.g. "Marx Halle", \
              "Madison Square Garden", "O2 Arena"). DO NOT use seat \
              category words like "Stehplatz", "Sitzplatz", "Standing", \
              "General Admission". DO NOT use ticket types or pricing tiers.
            - "date" must be ISO 8601 format YYYY-MM-DD. European date \
              formats like "13.05.2026" are day.month.year — convert to \
              "2026-05-13". German month names: Januar, Februar, März, \
              April, Mai, Juni, Juli, August, September, Oktober, \
              November, Dezember.
            - "doorsTime" and "showTime" must be 24-hour HH:MM. Common \
              labels: "Doors", "Einlass", "Show", "Beginn", "Showtime".
            - "flightNumber" must include the carrier code (e.g. "UA 1471").
            - Airport codes must be IATA 3-letter codes (e.g. "SFO", "JFK").
            - Leave fields empty if not in the text. DO NOT invent.
            """
        }
        do {
            let response = try await session.respond(
                to: "Extract ticket details from this text:\n\n\(text)",
                generating: ShareExtractionGuess.self
            )
            NSLog("[Lumoria] FM extracted: %@", String(describing: response.content))
            return response.content
        } catch {
            NSLog("[Lumoria] FM call failed: %@", String(describing: error))
            return nil
        }
        #else
        return nil
        #endif
    }
}

#if canImport(FoundationModels)

/// Structured output the model fills in. Properties are declared in
/// "logical generation order" per Apple's Foundation Models guidance —
/// `category` first so subsequent fields can be conditional on it,
/// then concert-shaped fields, then plane-shaped fields.
///
/// Date/time fields use ISO-style strings (YYYY-MM-DD / HH:MM)
/// because the model is more reliable at producing well-formed
/// strings than parsing locale-specific date formats. Conversion to
/// `Date` happens in `toConcertFields()` / `toPlaneFields()` with a
/// fixed `en_US_POSIX` formatter so the result is locale-independent.
@available(iOS 26.0, *)
@Generable
struct ShareExtractionGuess: Sendable {
    @Guide(description: "Type of ticket. Must be exactly 'plane', 'concert', or 'unknown'.")
    var category: String

    // Concert fields

    @Guide(description: "Artist or performer name for concert tickets")
    var artist: String?

    @Guide(description: "Tour name for concert tickets")
    var tourName: String?

    @Guide(description: "Actual venue name (e.g. 'Madison Square Garden', 'Marx Halle', 'Wiener Stadthalle Halle D'). NOT seat-type words like 'Stehplatz'.")
    var venue: String?

    @Guide(description: "Order or ticket reference number")
    var ticketNumber: String?

    @Guide(description: "Event date in ISO 8601 format YYYY-MM-DD (e.g. '2026-05-13' for 13 May 2026)")
    var date: String?

    @Guide(description: "Doors-open time in 24-hour HH:MM format (e.g. '19:00')")
    var doorsTime: String?

    @Guide(description: "Show start time in 24-hour HH:MM format (e.g. '20:00')")
    var showTime: String?

    // Plane fields

    @Guide(description: "Flight number with carrier code (e.g. 'UA 1471')")
    var flightNumber: String?

    @Guide(description: "Origin airport IATA 3-letter code (e.g. 'SFO')")
    var originAirport: String?

    @Guide(description: "Destination airport IATA 3-letter code (e.g. 'JFK')")
    var destinationAirport: String?

    @Guide(description: "Departure date in ISO 8601 format YYYY-MM-DD")
    var departureDate: String?

    @Guide(description: "Departure time in 24-hour HH:MM format")
    var departureTime: String?

    @Guide(description: "Gate identifier for plane tickets")
    var gate: String?

    @Guide(description: "Seat designator (e.g. '14C')")
    var seat: String?

    @Guide(description: "Terminal identifier for plane tickets")
    var terminal: String?

    func toPlaneFields() -> SharePlaneFields {
        var fields = SharePlaneFields()
        fields.flightNumber = flightNumber ?? ""
        fields.originCode = originAirport ?? ""
        fields.destinationCode = destinationAirport ?? ""
        fields.gate = gate ?? ""
        fields.seat = seat ?? ""
        fields.terminal = terminal ?? ""
        if let departure = combine(date: departureDate, time: departureTime) {
            fields.departureDate = departure
        } else if let departure = parseISODate(departureDate) {
            fields.departureDate = departure
        }
        return fields
    }

    func toConcertFields() -> ShareConcertFields {
        var fields = ShareConcertFields()
        fields.artist = artist ?? ""
        fields.tourName = tourName ?? ""
        fields.venue = venue ?? ""
        fields.ticketNumber = ticketNumber ?? ""
        let day = parseISODate(date)
        fields.date = day
        fields.doorsTime = combine(date: date, time: doorsTime) ?? day
        fields.showTime = combine(date: date, time: showTime) ?? day
        return fields
    }

    // MARK: - Helpers

    /// Parses an ISO `YYYY-MM-DD` date string. Returns nil for any
    /// other format — the model is instructed to use this format,
    /// and silently coercing other shapes would mask prompt issues.
    private func parseISODate(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }

    /// Combines an ISO date and an HH:MM time string into a single
    /// `Date`. Used for `doorsTime`, `showTime`, and `departureTime`.
    private func combine(date: String?, time: String?) -> Date? {
        guard let day = parseISODate(date),
              let time, !time.isEmpty else { return nil }
        let parts = time.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0..<24).contains(hour),
              (0..<60).contains(minute) else { return nil }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute
        return cal.date(from: comps)
    }
}

#endif
