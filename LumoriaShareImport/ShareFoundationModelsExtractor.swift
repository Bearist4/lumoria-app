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
            "You extract ticket details from confirmation emails or " +
            "screenshots of confirmation emails. Identify whether the " +
            "text describes a plane ticket or a concert ticket, then " +
            "fill only the fields you can confidently extract from the " +
            "given text. Leave any field you are unsure about empty. " +
            "DO NOT invent values that are not present in the text. " +
            "Airport codes must be IATA 3-letter codes when present."
        }
        do {
            let response = try await session.respond(
                to: "Extract ticket details from this text:\n\n\(text)",
                generating: ShareExtractionGuess.self
            )
            NSLog("[Lumoria] FM extracted category=%@", response.content.category)
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

/// Structured output the model fills in. Fields beyond `category`
/// are optional — the model leaves them empty when the input
/// doesn't include them, per the system instructions.
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

    @Guide(description: "Venue name (e.g. 'Madison Square Garden', 'Marx Halle')")
    var venue: String?

    @Guide(description: "Order or ticket reference number")
    var ticketNumber: String?

    // Plane fields

    @Guide(description: "Flight number with carrier code (e.g. 'UA 1471')")
    var flightNumber: String?

    @Guide(description: "Origin airport IATA 3-letter code (e.g. 'SFO')")
    var originAirport: String?

    @Guide(description: "Destination airport IATA 3-letter code (e.g. 'JFK')")
    var destinationAirport: String?

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
        return fields
    }

    func toConcertFields() -> ShareConcertFields {
        var fields = ShareConcertFields()
        fields.artist = artist ?? ""
        fields.tourName = tourName ?? ""
        fields.venue = venue ?? ""
        fields.ticketNumber = ticketNumber ?? ""
        return fields
    }
}

#endif
