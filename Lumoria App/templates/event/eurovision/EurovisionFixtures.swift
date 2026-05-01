//
//  EurovisionFixtures.swift
//  Lumoria App
//
//  Pinned facts for the Eurovision 2026 grand final. Date and venue are
//  not user-editable — every Eurovision ticket points at the same
//  real-world event, so we centralise the values here so the form, the
//  payload builder, the memory-map pin, and the changelog never drift.
//
//  Update only when the EBU publishes a confirmed change (e.g. venue
//  swap or date shift); a one-line PR here ripples through every call
//  site automatically.
//

import Foundation

enum EurovisionFixtures {

    /// Wiener Stadthalle Halle D, Vienna, Austria. Coordinates from
    /// Wikidata Q659078 — accurate enough for the memory-map pin.
    static let venue: String = "Stadthalle Halle D"
    static let venueFullName: String = "Wiener Stadthalle Halle D"
    static let city: String = "Vienna"
    static let country: String = "Austria"
    static let countryCode: String = "AT"
    static let venueLatitude: Double = 48.2025
    static let venueLongitude: Double = 16.3361

    /// 16 May 2026 — official grand-final date. Constructed once at
    /// load via the en-US-POSIX calendar so locale changes can't shift
    /// the pinned day.
    static let date: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 16
        components.hour = 21
        components.minute = 0
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna") ?? .current
        return calendar.date(from: components) ?? Date()
    }()

    /// `TicketLocation` slot used for the memory-map pin. Same shape
    /// as airport / station fixtures elsewhere in the app so the pin
    /// rendering and country-flag helper work without special-casing
    /// the Eurovision template.
    static var venueLocation: TicketLocation {
        TicketLocation(
            name: venueFullName,
            subtitle: nil,
            city: city,
            country: country,
            countryCode: countryCode,
            lat: venueLatitude,
            lng: venueLongitude,
            kind: .venue
        )
    }
}
