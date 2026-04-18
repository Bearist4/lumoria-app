//
//  ExpressTicket.swift
//  Lumoria App
//
//  Payload for the "Express" train ticket template — bilingual
//  (Latin + Kanji) Shinkansen-style boarding pass.
//

import Foundation

/// Train-ticket payload. City names ship in two scripts — the Latin
/// form is what the user types; the Kanji form is auto-suggested by
/// `CityNameTranslator` when a known city is recognized, but always
/// remains user-editable.
struct ExpressTicket: Codable, Hashable {
    var trainType: String          // e.g. "Shinkansen N700"
    var trainNumber: String        // e.g. "Hikari 503"
    var cabinClass: String         // e.g. "Green Car"
    var originCity: String         // Latin, e.g. "Tokyo"
    var originCityKanji: String    // CJK, e.g. "東京"
    var destinationCity: String    // Latin, e.g. "Osaka"
    var destinationCityKanji: String // CJK, e.g. "大阪"
    var date: String               // e.g. "14.03.2026"
    var departureTime: String      // e.g. "06:33"
    var arrivalTime: String        // e.g. "09:10"
    var car: String                // e.g. "7"
    var seat: String               // e.g. "14A"
    var ticketNumber: String       // e.g. "0000000000"
}
