//
//  AirlineDatabase.swift
//  Lumoria App
//
//  Static catalog of major airlines. Used by `LumoriaAirlineField` for
//  autocomplete and to provide the 2-letter IATA carrier code that
//  pre-fills the flight-number field.
//
//  To expand: append entries to `seed`. Name + IATA code are the only
//  required fields; country is for display in the dropdown row.
//

import Foundation

struct Airline: Identifiable, Hashable, Codable {
    var id: String { iata }
    /// 2-letter IATA airline code (e.g. "AF", "BA", "LH").
    let iata: String
    let name: String
    let country: String
    let countryCode: String
}

enum AirlineDatabase {

    /// Minimum query length before suggestions are returned. Keeps the
    /// dropdown quiet while the user is still typing single characters.
    static let queryMinimumLength = 3

    /// Returns up to 10 airlines matching `query`. Matches on name prefix
    /// or IATA code exact.
    static func search(_ query: String) -> [Airline] {
        let q = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard q.count >= queryMinimumLength else { return [] }
        return seed
            .filter { airline in
                airline.name.lowercased().contains(q)
                    || airline.iata.lowercased() == q
            }
            .prefix(10)
            .map { $0 }
    }

    // MARK: - Seed

    /// ~80 major passenger airlines. Alphabetized by IATA code.
    static let seed: [Airline] = [
        .init(iata: "5J", name: "Cebu Pacific",           country: "Philippines",      countryCode: "PH"),
        .init(iata: "6E", name: "IndiGo",                 country: "India",            countryCode: "IN"),
        .init(iata: "7C", name: "Jeju Air",               country: "South Korea",      countryCode: "KR"),
        .init(iata: "AA", name: "American Airlines",      country: "United States",    countryCode: "US"),
        .init(iata: "AC", name: "Air Canada",             country: "Canada",           countryCode: "CA"),
        .init(iata: "AI", name: "Air India",              country: "India",            countryCode: "IN"),
        .init(iata: "AK", name: "AirAsia",                country: "Malaysia",         countryCode: "MY"),
        .init(iata: "AM", name: "Aeroméxico",             country: "Mexico",           countryCode: "MX"),
        .init(iata: "AR", name: "Aerolíneas Argentinas",  country: "Argentina",        countryCode: "AR"),
        .init(iata: "AS", name: "Alaska Airlines",        country: "United States",    countryCode: "US"),
        .init(iata: "AT", name: "Royal Air Maroc",        country: "Morocco",          countryCode: "MA"),
        .init(iata: "AV", name: "Avianca",                country: "Colombia",         countryCode: "CO"),
        .init(iata: "AY", name: "Finnair",                country: "Finland",          countryCode: "FI"),
        .init(iata: "AZ", name: "ITA Airways",            country: "Italy",            countryCode: "IT"),
        .init(iata: "B6", name: "JetBlue Airways",        country: "United States",    countryCode: "US"),
        .init(iata: "BA", name: "British Airways",        country: "United Kingdom",   countryCode: "GB"),
        .init(iata: "BR", name: "EVA Air",                country: "Taiwan",           countryCode: "TW"),
        .init(iata: "BT", name: "airBaltic",              country: "Latvia",           countryCode: "LV"),
        .init(iata: "CA", name: "Air China",              country: "China",            countryCode: "CN"),
        .init(iata: "CI", name: "China Airlines",         country: "Taiwan",           countryCode: "TW"),
        .init(iata: "CM", name: "Copa Airlines",          country: "Panama",           countryCode: "PA"),
        .init(iata: "CX", name: "Cathay Pacific",         country: "Hong Kong",        countryCode: "HK"),
        .init(iata: "CZ", name: "China Southern",         country: "China",            countryCode: "CN"),
        .init(iata: "DL", name: "Delta Air Lines",        country: "United States",    countryCode: "US"),
        .init(iata: "EK", name: "Emirates",               country: "United Arab Emirates", countryCode: "AE"),
        .init(iata: "ET", name: "Ethiopian Airlines",     country: "Ethiopia",         countryCode: "ET"),
        .init(iata: "EW", name: "Eurowings",              country: "Germany",          countryCode: "DE"),
        .init(iata: "EY", name: "Etihad Airways",         country: "United Arab Emirates", countryCode: "AE"),
        .init(iata: "F9", name: "Frontier Airlines",      country: "United States",    countryCode: "US"),
        .init(iata: "FR", name: "Ryanair",                country: "Ireland",          countryCode: "IE"),
        .init(iata: "G3", name: "GOL Linhas Aéreas",      country: "Brazil",           countryCode: "BR"),
        .init(iata: "GA", name: "Garuda Indonesia",       country: "Indonesia",        countryCode: "ID"),
        .init(iata: "GF", name: "Gulf Air",               country: "Bahrain",          countryCode: "BH"),
        .init(iata: "HU", name: "Hainan Airlines",        country: "China",            countryCode: "CN"),
        .init(iata: "IB", name: "Iberia",                 country: "Spain",            countryCode: "ES"),
        .init(iata: "JL", name: "Japan Airlines",         country: "Japan",            countryCode: "JP"),
        .init(iata: "JQ", name: "Jetstar Airways",        country: "Australia",        countryCode: "AU"),
        .init(iata: "KE", name: "Korean Air",             country: "South Korea",      countryCode: "KR"),
        .init(iata: "KL", name: "KLM",                    country: "Netherlands",      countryCode: "NL"),
        .init(iata: "KQ", name: "Kenya Airways",          country: "Kenya",            countryCode: "KE"),
        .init(iata: "LA", name: "LATAM Airlines",         country: "Chile",            countryCode: "CL"),
        .init(iata: "LH", name: "Lufthansa",              country: "Germany",          countryCode: "DE"),
        .init(iata: "LO", name: "LOT Polish Airlines",    country: "Poland",           countryCode: "PL"),
        .init(iata: "LX", name: "Swiss International",    country: "Switzerland",      countryCode: "CH"),
        .init(iata: "LY", name: "El Al",                  country: "Israel",           countryCode: "IL"),
        .init(iata: "MH", name: "Malaysia Airlines",      country: "Malaysia",         countryCode: "MY"),
        .init(iata: "MS", name: "EgyptAir",               country: "Egypt",            countryCode: "EG"),
        .init(iata: "MU", name: "China Eastern Airlines", country: "China",            countryCode: "CN"),
        .init(iata: "NH", name: "All Nippon Airways",     country: "Japan",            countryCode: "JP"),
        .init(iata: "NK", name: "Spirit Airlines",        country: "United States",    countryCode: "US"),
        .init(iata: "NZ", name: "Air New Zealand",        country: "New Zealand",      countryCode: "NZ"),
        .init(iata: "OS", name: "Austrian Airlines",      country: "Austria",          countryCode: "AT"),
        .init(iata: "OZ", name: "Asiana Airlines",        country: "South Korea",      countryCode: "KR"),
        .init(iata: "PC", name: "Pegasus Airlines",       country: "Turkey",           countryCode: "TR"),
        .init(iata: "PR", name: "Philippine Airlines",    country: "Philippines",      countryCode: "PH"),
        .init(iata: "QF", name: "Qantas",                 country: "Australia",        countryCode: "AU"),
        .init(iata: "QR", name: "Qatar Airways",          country: "Qatar",            countryCode: "QA"),
        .init(iata: "RJ", name: "Royal Jordanian",        country: "Jordan",           countryCode: "JO"),
        .init(iata: "SA", name: "South African Airways",  country: "South Africa",     countryCode: "ZA"),
        .init(iata: "SG", name: "SpiceJet",               country: "India",            countryCode: "IN"),
        .init(iata: "SK", name: "SAS Scandinavian",       country: "Sweden",           countryCode: "SE"),
        .init(iata: "SQ", name: "Singapore Airlines",     country: "Singapore",        countryCode: "SG"),
        .init(iata: "SU", name: "Aeroflot",               country: "Russia",           countryCode: "RU"),
        .init(iata: "SV", name: "Saudia",                 country: "Saudi Arabia",     countryCode: "SA"),
        .init(iata: "TG", name: "Thai Airways",           country: "Thailand",         countryCode: "TH"),
        .init(iata: "TK", name: "Turkish Airlines",       country: "Turkey",           countryCode: "TR"),
        .init(iata: "TP", name: "TAP Air Portugal",       country: "Portugal",         countryCode: "PT"),
        .init(iata: "TR", name: "Scoot",                  country: "Singapore",        countryCode: "SG"),
        .init(iata: "U2", name: "easyJet",                country: "United Kingdom",   countryCode: "GB"),
        .init(iata: "UA", name: "United Airlines",        country: "United States",    countryCode: "US"),
        .init(iata: "UK", name: "Vistara",                country: "India",            countryCode: "IN"),
        .init(iata: "VA", name: "Virgin Australia",       country: "Australia",        countryCode: "AU"),
        .init(iata: "VN", name: "Vietnam Airlines",       country: "Vietnam",          countryCode: "VN"),
        .init(iata: "VY", name: "Vueling",                country: "Spain",            countryCode: "ES"),
        .init(iata: "W6", name: "Wizz Air",               country: "Hungary",          countryCode: "HU"),
        .init(iata: "WN", name: "Southwest Airlines",     country: "United States",    countryCode: "US"),
        .init(iata: "WS", name: "WestJet",                country: "Canada",           countryCode: "CA"),
        .init(iata: "WY", name: "Oman Air",               country: "Oman",             countryCode: "OM"),
        .init(iata: "AF", name: "Air France",             country: "France",           countryCode: "FR"),
    ]
}

// MARK: - Helpers

extension Airline {
    /// The carrier country's flag emoji. Derived the same way as in
    /// `TicketLocation` — 2-letter ISO code → regional indicator symbols.
    var flagEmoji: String? {
        guard countryCode.count == 2 else { return nil }
        let base: UInt32 = 127397
        var out = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            guard let paired = UnicodeScalar(base + scalar.value) else { return nil }
            out.unicodeScalars.append(paired)
        }
        return out
    }
}
