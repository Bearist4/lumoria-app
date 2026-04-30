//
//  TransitCatalog.swift
//  Lumoria App
//
//  In-memory model + bundled-resource loader for the per-city GTFS
//  catalogs produced by `scripts/gtfs-import/import.py`. One catalog
//  per city; each is a list of lines and each line is an ordered list
//  of stations with official brand colour + name + coordinate.
//
//  The catalog is the single source of truth for underground-ticket
//  line metadata — line short name, line name, operator, colour, stop
//  count. When the user changes an origin / destination station in
//  the funnel, the form re-runs `TransitRouter` over this catalog
//  and the ticket preview reflects whatever the router says.
//

import Foundation

// MARK: - DTO (mirrors the JSON shape)

/// A bundled GTFS-derived catalog for one operator in one city.
struct TransitCatalog: Codable {
    let city: String
    let operatorName: String
    let generatedAt: String
    let source: String
    let lines: [TransitLine]

    enum CodingKeys: String, CodingKey {
        case city
        case operatorName = "operator"
        case generatedAt
        case source
        case lines
    }
}

/// One rider-facing line within a catalog — "U1", "Central",
/// "Ginza". Station list is the canonical ordered sequence from the
/// longest scheduled trip on that line.
struct TransitLine: Codable, Hashable {
    /// Stable identifier, usually the `shortName` (catalog is deduped
    /// by shortName during import).
    let id: String
    /// 1–3 character code printed on the badge ("U1", "E").
    let shortName: String
    /// Full name — "U1 Leopoldau – Reumannplatz".
    let longName: String
    /// Hex colour (`"#E4002B"`) from the operator's `routes.txt`.
    let color: String
    /// Text colour to use on top of `color`.
    let textColor: String
    /// GTFS `route_type` int — drives the mode icon in the picker and
    /// lets the map differentiate subway vs bus vs tram. Optional so
    /// older catalogs without the field still decode.
    let mode: Int?
    /// Operator name for this specific line. Optional — when nil the
    /// catalog-level `operatorName` is used. Set when a city has more
    /// than one operator (e.g. Tokyo: Tokyo Metro + Toei) so each
    /// ticket carries the right company on the badge.
    let `operator`: String?
    let stations: [TransitStation]
}

/// GTFS route-type interpretation. Mirrors the numbers defined in
/// https://developers.google.com/transit/gtfs/reference#routestxt
/// and adds SF-Symbol-friendly convenience accessors for the picker
/// and ticket UI.
enum TransitMode: Int {
    case tram        = 0
    case subway      = 1
    case rail        = 2
    case bus         = 3
    case ferry       = 4
    case cableTram   = 5
    case aerialLift  = 6
    case funicular   = 7
    case trolleybus  = 11
    case monorail    = 12

    /// Optional-aware factory. Deliberately named `from(rawValue:)`
    /// instead of overloading `init?(rawValue:)` — a custom
    /// `init?(rawValue:)` on a raw-value enum silently shadows the
    /// synthesized integer init, and then the compiler's implicit
    /// `Int → Int?` conversion turns `TransitMode(rawValue: 0)` into
    /// a recursive call. Stack-overflow crash, no backtrace.
    ///
    /// Explicit guard-form is used over `.flatMap(TransitMode.init…)`
    /// so the call site unambiguously dispatches to the synthesized
    /// `init?(rawValue: Int)` — no method-reference resolution
    /// gymnastics for the compiler to trip on.
    static func from(rawValue: Int?) -> TransitMode? {
        guard let raw = rawValue else { return nil }
        return TransitMode(rawValue: raw)
    }

    /// SF Symbol name. Uses widely-available symbols so the UI
    /// renders on every supported iOS version.
    var symbol: String {
        switch self {
        case .tram, .cableTram:              return "tram.fill"
        case .subway:                        return "tram.tunnel.fill"
        case .rail:                          return "train.side.front.car"
        case .bus, .trolleybus:              return "bus.fill"
        case .ferry:                         return "ferry.fill"
        case .aerialLift, .funicular:        return "cablecar.fill"
        case .monorail:                      return "tram.fill"
        }
    }

    /// Short human label, occasionally surfaced in the suggestion
    /// row when the line's short name is ambiguous.
    var displayName: String {
        switch self {
        case .tram:        return "Tram"
        case .subway:      return "Metro"
        case .rail:        return "Rail"
        case .bus:         return "Bus"
        case .ferry:       return "Ferry"
        case .cableTram:   return "Cable tram"
        case .aerialLift:  return "Cable car"
        case .funicular:   return "Funicular"
        case .trolleybus:  return "Trolley"
        case .monorail:    return "Monorail"
        }
    }
}

extension TransitLine {
    /// Decoded mode, or `.bus` as a neutral fallback if the catalog
    /// predates the `mode` field.
    var resolvedMode: TransitMode {
        TransitMode.from(rawValue: mode) ?? .bus
    }

    /// Compact, rider-friendly label used in the form dropdowns.
    /// Returns the bare `shortName` when it already stands alone:
    /// numeric / mixed codes (Vienna's "U1", NYC's "L"), word codes
    /// that already read as the line name (Melbourne's "Alamein",
    /// "Belgrave"). Single-letter codes whose `longName` carries
    /// useful name info expand to "name (code)" — Tokyo's
    /// "Chiyoda (C)" being the canonical case.
    var displayLabel: String {
        // Word-style short names (≥ 3 alphabetic characters) are
        // already the rider-facing identity — no need to expand them
        // with the route description (which is usually a "From - To"
        // string for these networks).
        let isWordCode = shortName.count >= 3
            && shortName.allSatisfy(\.isLetter)
        if isWordCode { return shortName }

        let stripped = longName
            .replacingOccurrences(of: " Line", with: "")
            .replacingOccurrences(of: " line", with: "")
            .trimmingCharacters(in: .whitespaces)
        var nameOnly = stripped
        if nameOnly.hasPrefix(shortName + " ") {
            nameOnly = String(nameOnly.dropFirst(shortName.count + 1))
        }
        // Drop residual separators left after stripping a prefix.
        let trimChars = CharacterSet(charactersIn: "- ·/–\t")
        nameOnly = nameOnly.trimmingCharacters(in: trimChars)

        if nameOnly.isEmpty || nameOnly == shortName || nameOnly.count > 14 {
            return shortName
        }
        return "\(nameOnly) (\(shortName))"
    }
}

/// One station entry on a line. `id` is the GTFS `stop_id` after
/// parent-station resolution.
struct TransitStation: Codable, Hashable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
}

// MARK: - Loader

/// Facade that loads and caches bundled catalogs on first access.
/// Names map 1-to-1 to the JSON filenames under
/// `Lumoria App/resources/transit/<Name>.json` — e.g. `.vienna`
/// loads `Vienna.json`.
enum TransitCatalogLoader {

    /// Known bundled catalogs. Add a new case + bundle the matching
    /// JSON file when a new city is imported.
    enum City: String, CaseIterable, Identifiable, Hashable, Codable {
        case vienna    = "Vienna"
        case newYork   = "NewYork"
        case paris     = "Paris"
        case nantes    = "Nantes"
        case lyon      = "Lyon"
        case bordeaux  = "Bordeaux"
        case marseille = "Marseille"
        case zurich    = "Zurich"
        case berlin    = "Berlin"
        case london    = "London"
        case stockholm = "Stockholm"
        case tokyo     = "Tokyo"
        case melbourne = "Melbourne"

        var id: String { rawValue }
        var resourceName: String { rawValue }

        /// Common city-name aliases the MapKit locality hint might
        /// use — "NYC" for New York, "Wien" for Vienna.
        var aliases: [String] {
            switch self {
            case .vienna:    return ["Vienna", "Wien"]
            case .newYork:   return ["New York", "NYC", "New York City", "NewYork"]
            case .paris:     return ["Paris", "Île-de-France", "Ile-de-France"]
            case .nantes:    return ["Nantes", "Nantes Métropole"]
            case .lyon:      return ["Lyon", "Grand Lyon", "Lyon Métropole"]
            case .bordeaux:  return ["Bordeaux", "Bordeaux Métropole"]
            case .marseille: return ["Marseille", "Aix-Marseille-Provence"]
            case .zurich:    return ["Zurich", "Zürich"]
            case .berlin:    return ["Berlin", "Berlin-Brandenburg", "VBB"]
            case .london:    return ["London", "Greater London", "City of London", "TfL"]
            case .stockholm: return ["Stockholm", "Stockholms län", "SL"]
            case .tokyo:     return ["Tokyo", "Tōkyō", "東京", "Tokyo Metro", "Toei", "Tokyo-to"]
            case .melbourne: return ["Melbourne", "Greater Melbourne", "Victoria", "VIC"]
            }
        }
    }

    /// Returns the catalog for `city`, loading + decoding from the
    /// app bundle on first call. Subsequent calls hit the in-memory
    /// cache. Returns `nil` only when the JSON file is missing from
    /// the bundle or decoding fails — both bugs worth surfacing in a
    /// crash reporter if they ever happen in production.
    @MainActor
    static func catalog(for city: City) -> TransitCatalog? {
        if let cached = cache[city] { return cached }
        guard let url = Bundle.main.url(forResource: city.resourceName, withExtension: "json") else {
            print("[transit] bundle missing resource \(city.resourceName).json")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(TransitCatalog.self, from: data)
            cache[city] = catalog
            return catalog
        } catch {
            print("[transit] failed to decode \(city.resourceName).json:", error)
            return nil
        }
    }

    /// Finds the catalog whose name best matches a hint (typically a
    /// `TicketLocation.city` string from MapKit). Matches any alias
    /// (so "Wien" resolves to Vienna, "NYC" to New York). Returns
    /// `nil` when no bundled catalog covers the hint — the caller
    /// falls back to manual line entry.
    @MainActor
    static func catalog(forCityHint hint: String) -> TransitCatalog? {
        let needle = hint.lowercased()
        for city in City.allCases {
            for alias in city.aliases {
                let a = alias.lowercased()
                if a.contains(needle) || needle.contains(a) {
                    return catalog(for: city)
                }
            }
        }
        return nil
    }

    @MainActor private static var cache: [City: TransitCatalog] = [:]
}

// MARK: - Derived indexes

extension TransitCatalog {
    /// Stations indexed by `id` for O(1) lookup during routing.
    var stationsById: [String: TransitStation] {
        var out: [String: TransitStation] = [:]
        for line in lines {
            for station in line.stations {
                out[station.id] = station
            }
        }
        return out
    }

    /// Lines serving a given `stop_id`.
    var linesByStation: [String: [TransitLine]] {
        var out: [String: [TransitLine]] = [:]
        for line in lines {
            for station in line.stations {
                out[station.id, default: []].append(line)
            }
        }
        return out
    }

    /// Lines serving a given station-name-based transfer key. Producers
    /// like Wiener Linien ship a different `stop_id` per platform
    /// (Stephansplatz-on-U1 ≠ Stephansplatz-on-U3 by id), so transfer
    /// logic must group by name. A station's `transferKey` is its
    /// normalized name. Use `linesByCluster` instead in journey
    /// routing — `transferKey` produces phantom transfers when a city
    /// has two unrelated stops sharing a name (Nantes "Jean Jaurès"
    /// on bus 96 vs tram 3, 9 km apart).
    var linesByTransferKey: [String: [TransitLine]] {
        var out: [String: [TransitLine]] = [:]
        for line in lines {
            for station in line.stations {
                let key = Self.transferKey(station.name)
                out[key, default: []].append(line)
            }
        }
        return out
    }

    // MARK: - Physical-station clustering

    /// Cluster table — same normalized name AND geographically close
    /// (≤ 250 m). The right transfer graph for the router: name-only
    /// matching collapses physically separate stops sharing a name,
    /// inventing impossible transfers (Nantes' bus 96 "Jean Jaurès"
    /// 9 km north of the tram-3 stop of the same name).
    struct Clusters {
        /// Cluster key per station id. Stable within one catalog load.
        let keyByStationId: [String: String]
        /// Lines serving each cluster.
        let linesByCluster: [String: [TransitLine]]
        /// Per base name (the normalized transfer key), the list of
        /// cluster centroids — used to map a `(name, coord)` tuple
        /// to its cluster.
        let clustersByBaseKey: [String: [(key: String, lat: Double, lng: Double)]]
    }

    /// Cluster table for this catalog. Computed once on first access
    /// and cached per city — clustering iterates every station in
    /// every line, so recomputing on every call (Tokyo: ~6k stations)
    /// freezes the picker dropdown's hot loop.
    var clusters: Clusters {
        if let cached = Self.clusterCache.get(city) { return cached }
        let computed = computeClusters()
        Self.clusterCache.set(city, computed)
        return computed
    }

    private func computeClusters() -> Clusters {
        var keyByStationId: [String: String] = [:]
        var clustersByBaseKey: [String: [(key: String, stations: [TransitStation])]] = [:]

        for line in lines {
            for station in line.stations {
                if keyByStationId[station.id] != nil { continue }
                let baseKey = Self.transferKey(station.name)
                var matched: String? = nil
                if let candidates = clustersByBaseKey[baseKey] {
                    for c in candidates {
                        let centroid = Self.centroid(of: c.stations)
                        let d = Self.haversineMeters(
                            lat1: station.lat, lng1: station.lng,
                            lat2: centroid.lat, lng2: centroid.lng
                        )
                        if d <= Self.clusterRadiusMeters {
                            matched = c.key
                            break
                        }
                    }
                }
                let key: String
                if let m = matched {
                    key = m
                    if var list = clustersByBaseKey[baseKey],
                       let idx = list.firstIndex(where: { $0.key == m }) {
                        list[idx].stations.append(station)
                        clustersByBaseKey[baseKey] = list
                    }
                } else {
                    let n = clustersByBaseKey[baseKey]?.count ?? 0
                    key = "\(baseKey)#\(n)"
                    clustersByBaseKey[baseKey, default: []].append((key, [station]))
                }
                keyByStationId[station.id] = key
            }
        }

        var linesByCluster: [String: [TransitLine]] = [:]
        for line in lines {
            var seen: Set<String> = []
            for station in line.stations {
                guard let key = keyByStationId[station.id] else { continue }
                if seen.insert(key).inserted {
                    linesByCluster[key, default: []].append(line)
                }
            }
        }

        var flat: [String: [(key: String, lat: Double, lng: Double)]] = [:]
        for (baseKey, list) in clustersByBaseKey {
            flat[baseKey] = list.map {
                let c = Self.centroid(of: $0.stations)
                return ($0.key, c.lat, c.lng)
            }
        }

        return Clusters(
            keyByStationId: keyByStationId,
            linesByCluster: linesByCluster,
            clustersByBaseKey: flat
        )
    }

    /// Thread-safe per-city cache for cluster tables. Catalogs are
    /// loaded on the main actor but the router reads from arbitrary
    /// contexts, so a plain `@MainActor` static would force every
    /// caller onto the main actor. NSLock is sufficient — accesses
    /// are write-once-per-city, read-many.
    private final class ClusterCache: @unchecked Sendable {
        private var storage: [String: Clusters] = [:]
        private let lock = NSLock()
        func get(_ city: String) -> Clusters? {
            lock.lock(); defer { lock.unlock() }
            return storage[city]
        }
        func set(_ city: String, _ value: Clusters) {
            lock.lock(); defer { lock.unlock() }
            storage[city] = value
        }
    }
    private static let clusterCache = ClusterCache()

    /// Lines bucketed by cluster key. Use this in the router instead
    /// of `linesByTransferKey`.
    var linesByCluster: [String: [TransitLine]] { clusters.linesByCluster }

    /// Resolves a `(name, coord)` tuple to its catalog cluster, or
    /// nil when no cluster of that name sits within radius. Used by
    /// the router to look up the cluster for an externally-supplied
    /// origin / destination station.
    func clusterKey(name: String, lat: Double, lng: Double) -> String? {
        let baseKey = Self.transferKey(name)
        guard let candidates = clusters.clustersByBaseKey[baseKey] else { return nil }
        var best: (key: String, distance: Double)?
        for c in candidates {
            let d = Self.haversineMeters(
                lat1: lat, lng1: lng, lat2: c.lat, lng2: c.lng
            )
            if d <= Self.clusterRadiusMeters, best == nil || d < best!.distance {
                best = (c.key, d)
            }
        }
        return best?.key
    }

    /// Cluster key for a station already in this catalog. Falls back
    /// to the bare name-based transfer key if the station isn't in
    /// the cached map (shouldn't happen for catalog-resident stations
    /// but keeps the call site total).
    func clusterKey(for station: TransitStation) -> String {
        clusters.keyByStationId[station.id]
            ?? Self.transferKey(station.name)
    }

    /// Two stations sharing a normalized name fall into the same
    /// cluster when their centroid distance is within this radius.
    /// Sized to fit legitimate large interchanges (Karlsplatz spans
    /// ~280 m across U1/U2/U4 platforms; Praterstern ~395 m) while
    /// still splitting unrelated stops that happen to share a name
    /// (Nantes "Jean Jaurès" tram vs bus, ~9 km apart).
    static var clusterRadiusMeters: Double { 500.0 }

    private static func centroid(
        of stations: [TransitStation]
    ) -> (lat: Double, lng: Double) {
        guard !stations.isEmpty else { return (0, 0) }
        let n = Double(stations.count)
        let lat = stations.reduce(0.0) { $0 + $1.lat } / n
        let lng = stations.reduce(0.0) { $0 + $1.lng } / n
        return (lat, lng)
    }

    /// Builds the canonical transfer key from a station name. Same
    /// rules as the name matcher so "Stephansplatz", "stephansplatz"
    /// and "Stephansplatz  " all share one key.
    static func transferKey(_ rawName: String) -> String {
        Self.normalize(rawName)
    }

    /// Best-effort station lookup by name. Case + diacritic
    /// insensitive, strips parenthesised hints, trailing
    /// " Station"-like suffixes, and common transit prefixes
    /// ("U1 ", "U-Bahn ", "S "). Used as the first-pass reconcile
    /// between a MapKit-picked station and a catalog entry.
    func station(byName name: String) -> TransitStation? {
        let target = Self.normalize(name)
        guard !target.isEmpty else { return nil }

        var best: (station: TransitStation, score: Int)? = nil
        for line in lines {
            for station in line.stations {
                let candidate = Self.normalize(station.name)
                if candidate == target { return station }
                if candidate.hasPrefix(target) || target.hasPrefix(candidate) {
                    let score = abs(candidate.count - target.count)
                    if best == nil || score < best!.score {
                        best = (station, score)
                    }
                }
                // Token-overlap fallback — "oberlaa u1" ↔ "oberlaa"
                // still matches when neither is a prefix of the
                // other but they share the distinctive word.
                if Self.tokensOverlap(candidate, target) {
                    let score = abs(candidate.count - target.count) + 50
                    if best == nil || score < best!.score {
                        best = (station, score)
                    }
                }
            }
        }
        return best?.station
    }

    /// Coordinate-based lookup: returns the catalog station closest
    /// to `coord`, provided it's within `maxMeters` — otherwise nil.
    /// This is the reliable reconciler because MapKit gives us a real
    /// platform coordinate even when its display name doesn't match
    /// the GTFS name ("Wien Oberlaa U1" vs "Oberlaa").
    func station(
        near coord: (lat: Double, lng: Double),
        maxMeters: Double = 300
    ) -> TransitStation? {
        var best: (station: TransitStation, distance: Double)? = nil
        for line in lines {
            for station in line.stations {
                let d = Self.haversineMeters(
                    lat1: coord.lat, lng1: coord.lng,
                    lat2: station.lat, lng2: station.lng
                )
                if d <= maxMeters, best == nil || d < best!.distance {
                    best = (station, d)
                }
            }
        }
        return best?.station
    }

    /// Resolves a MapKit-picked station to a catalog entry, using
    /// coordinate proximity first (authoritative) and name as a
    /// fallback for the rare case the catalog's coordinate drifted
    /// past the radius (very occasional on some GTFS feeds).
    func resolveStation(name: String, lat: Double, lng: Double) -> TransitStation? {
        if let near = station(near: (lat, lng)) { return near }
        return station(byName: name)
    }

    /// Normalises a station name so "Stephansplatz", "stephansplatz"
    /// and "Stephansplatz Station" compare equal, plus strips
    /// common line-code prefixes (Vienna's "U1 Oberlaa" → "oberlaa",
    /// Berlin's "S Hauptbahnhof" → "hauptbahnhof").
    private static func normalize(_ raw: String) -> String {
        var value = raw.folding(options: .diacriticInsensitive, locale: .current)
        value = value.lowercased()

        if let paren = value.firstIndex(of: "(") {
            value = String(value[..<paren])
        }
        for suffix in [" station", " railway station", " train station",
                       " bahnhof", " metro", " u-bahn", " u bahn"] {
            if value.hasSuffix(suffix) {
                value = String(value.dropLast(suffix.count))
            }
        }
        // Strip leading transit-line prefixes — "u1 oberlaa" →
        // "oberlaa". Only when followed by a space so "u1" as the
        // whole name (unlikely) isn't wiped out.
        let prefixes = ["u1 ", "u2 ", "u3 ", "u4 ", "u5 ", "u6 ",
                        "u-bahn ", "u bahn ", "s ", "rer ", "m "]
        for prefix in prefixes where value.hasPrefix(prefix) {
            value = String(value.dropFirst(prefix.count))
            break
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when the two normalised names share at least one token
    /// of length ≥ 4 — picks up cases where MapKit adds a district
    /// or operator qualifier that the catalog lacks.
    private static func tokensOverlap(_ a: String, _ b: String) -> Bool {
        let tokensA = Set(a.split(separator: " ").map(String.init).filter { $0.count >= 4 })
        let tokensB = Set(b.split(separator: " ").map(String.init).filter { $0.count >= 4 })
        return !tokensA.isDisjoint(with: tokensB)
    }

    private static func haversineMeters(
        lat1: Double, lng1: Double,
        lat2: Double, lng2: Double
    ) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let l1 = lat1 * .pi / 180
        let l2 = lat2 * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
              + sin(dLng / 2) * sin(dLng / 2) * cos(l1) * cos(l2)
        return 2 * r * asin(min(1, sqrt(h)))
    }
}
