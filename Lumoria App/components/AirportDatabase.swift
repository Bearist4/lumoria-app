//
//  AirportDatabase.swift
//  Lumoria App
//
//  Static catalog of every IATA-coded airport in the world (~9k entries),
//  loaded lazily from `Resources/airports.csv` (sourced from
//  github.com/lxndrblz/Airports — public CC-BY licence).
//
//  Used to resolve an IATA code from a coordinate when MapKit's search
//  result doesn't carry the IATA in the name. The previous hand-curated
//  150-airport seed missed regional fields like Nantes (NTE), Bordeaux
//  (BOD), Pisa (PSA) etc.; this version covers the full corpus so any
//  airport the user can pick from MapKit resolves to the correct code.
//

import CoreLocation
import Foundation

struct Airport: Hashable {
    let iata: String
    let name: String
    let city: String
    /// Full localised country name (e.g. "France"). Derived from the
    /// 2-letter `countryCode` via `Locale.current.localizedString`.
    let country: String
    /// 2-letter ISO country code (e.g. "FR").
    let countryCode: String
    let lat: Double
    let lng: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

enum AirportDatabase {

    /// Returns the nearest known airport within `radius` meters of `coord`,
    /// or nil if nothing matches. `radius` default is 10km — wide enough to
    /// cover a sprawling airport campus but tight enough to reject a city
    /// center that happens to sit near a smaller airstrip.
    static func nearest(
        to coord: CLLocationCoordinate2D,
        within radius: CLLocationDistance = 10_000
    ) -> Airport? {
        let target = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        var best: (airport: Airport, distance: CLLocationDistance)?
        // Quick lat-lng box filter before the (more expensive) `distance`
        // call — 10km ≈ 0.1° lat / 0.1° lng at most latitudes, so a
        // 0.15° box is a safe pre-cut over 9k records.
        let latBox = 0.15
        let lngBox = 0.15 / max(cos(coord.latitude * .pi / 180), 0.1)
        for airport in seed {
            guard abs(airport.lat - coord.latitude)  < latBox,
                  abs(airport.lng - coord.longitude) < lngBox else { continue }
            let candidate = CLLocation(latitude: airport.lat, longitude: airport.lng)
            let d = target.distance(from: candidate)
            if d <= radius, best == nil || d < best!.distance {
                best = (airport, d)
            }
        }
        return best?.airport
    }

    /// Direct lookup by 3-letter IATA code (case-insensitive). Used when
    /// importing tickets that already carry an explicit code.
    static func airport(byIATA code: String) -> Airport? {
        let key = code.uppercased()
        return iataIndex[key]
    }

    // MARK: - Seed (lazy-loaded from CSV)

    /// Parsed airport corpus. Lazy so the first lookup pays the cost
    /// once; subsequent calls hit the cached array.
    static let seed: [Airport] = loadFromCSV()

    private static let iataIndex: [String: Airport] = {
        var map: [String: Airport] = [:]
        for airport in seed {
            map[airport.iata] = airport
        }
        return map
    }()

    private static func loadFromCSV() -> [Airport] {
        guard let url = Bundle.main.url(forResource: "airports", withExtension: "csv") else {
            print("[AirportDatabase] airports.csv NOT FOUND in bundle")
            assertionFailure("airports.csv missing from bundle")
            return []
        }
        guard let data = try? Data(contentsOf: url) else {
            print("[AirportDatabase] failed to read airports.csv at \(url)")
            return []
        }
        guard let text = String(data: data, encoding: .utf8) else {
            print("[AirportDatabase] airports.csv not valid UTF-8")
            return []
        }
        var airports: [Airport] = []
        airports.reserveCapacity(9_500)

        // Column indices in the source CSV (header row order):
        // 0:code 1:icao 2:name 3:latitude 4:longitude 5:elevation
        // 6:url 7:time_zone 8:city_code 9:country 10:city
        // 11:state 12:county 13:type
        //
        // Use `components(separatedBy:)` rather than `split(separator:)` —
        // the source has CRLF line endings, and `String.split` with a "\n"
        // separator returned the whole file as one substring on the
        // simulator, leaving the seed silently empty.
        var isHeader = true
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine
            if line.isEmpty { continue }
            if isHeader { isHeader = false; continue }
            let fields = parseCSVLine(line)
            guard fields.count >= 11 else { continue }
            let iata = fields[0].trimmingCharacters(in: .whitespaces)
            guard iata.count == 3 else { continue }
            let name = fields[2].trimmingCharacters(in: .whitespaces)
            guard let lat = Double(fields[3]),
                  let lng = Double(fields[4]) else { continue }
            let countryCode = fields[9].trimmingCharacters(in: .whitespaces).uppercased()
            let city = fields[10].trimmingCharacters(in: .whitespaces)
            let country = Locale.current.localizedString(
                forRegionCode: countryCode
            ) ?? countryCode
            airports.append(Airport(
                iata: iata,
                name: name.isEmpty ? city : name,
                city: city.isEmpty ? name : city,
                country: country,
                countryCode: countryCode,
                lat: lat,
                lng: lng
            ))
        }
        return airports
    }

    /// Minimal CSV line parser that respects "quoted, fields, with
    /// commas". The lxndrblz/Airports corpus has a handful of those
    /// (county / state names with commas), so we can't just split.
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for c in line {
            if c == "\"" {
                inQuotes.toggle()
            } else if c == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(c)
            }
        }
        fields.append(current)
        return fields
    }
}
