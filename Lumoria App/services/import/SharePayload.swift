//
//  SharePayload.swift
//  Lumoria App
//
//  Value types passed between the share extension and the main app.
//  Primitive types only — no `TicketCategory`, no `FlightFormInput`,
//  no `EventFormInput`. The main-app `ShareImportTranslator` converts
//  these into the funnel's real form-input types. Keeping the
//  extension target free of those types means it doesn't have to
//  link SwiftUI/MapKit/Combine just to compile.
//

import Foundation

/// Raw text the share extension extracted from a shared item before
/// running classification. `image` carries the source PNG bytes when
/// present so the main app can attach it to the ticket later.
struct SharePayload: Codable, Equatable {
    var text: String
    var image: Data?
    var sourceURL: URL?
}

/// Classification outcome for a payload. `category` is nil when no
/// scorecard cleared the threshold; the funnel falls back to the
/// category picker in that case.
///
/// `category` is a `String?` (`"plane"` or `"concert"`) — not
/// `TicketCategory` — to keep this file linkable into the extension
/// target without dragging in `NewTicketFunnel.swift`.
struct ShareClassification: Codable, Equatable {
    var category: String?
    var confidence: Double
    var signals: [String]
}

/// Plane-shaped fields extracted from text. Mirrors the subset of
/// `FlightFormInput` we can reasonably populate from OCR'd text.
/// Strings default to "" so the translator can do a straight copy.
struct SharePlaneFields: Codable, Equatable {
    var airline: String = ""
    var flightNumber: String = ""
    var originCode: String = ""
    var destinationCode: String = ""
    var gate: String = ""
    var seat: String = ""
    var terminal: String = ""
    var departureDate: Date?
}

/// Concert-shaped fields extracted from text. Mirrors the subset of
/// `EventFormInput` we can reasonably populate.
struct ShareConcertFields: Codable, Equatable {
    var artist: String = ""
    var tourName: String = ""
    var venue: String = ""
    var ticketNumber: String = ""
    var date: Date?
    var doorsTime: Date?
    var showTime: Date?
}

/// What the extension hands off to the main app. JSON-only contract.
/// One of `flight` / `event` is populated when classification
/// succeeded; both nil means the funnel will open at the category
/// picker with `payload.text` available for the user.
struct ShareImportResult: Codable, Equatable {
    var classification: ShareClassification
    var flight: SharePlaneFields?
    var event: ShareConcertFields?
    var payload: SharePayload
}
