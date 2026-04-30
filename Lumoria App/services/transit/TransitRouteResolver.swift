//
//  TransitRouteResolver.swift
//  Lumoria App
//
//  Resolves a transit ticket against the bundled GTFS catalogs into
//  the ordered list of station coordinates between origin and
//  destination — the polyline drawn on the ticket-detail map.
//
//  No live MapKit routing is involved: `MKDirections` transit mode
//  doesn't return polylines, so the catalog's per-line station list
//  is the source of truth. Segments are straight station-to-station;
//  true rail-curve geometry would require GTFS `shapes.txt` (not
//  bundled today).
//

import CoreLocation
import Foundation

/// Polyline path shown on the detail map for a transit ticket.
struct TransitRoutePath {
    let origin: TicketLocation
    let destination: TicketLocation
    /// Origin → every intermediate stop → destination, inclusive.
    let coordinates: [CLLocationCoordinate2D]
    /// Hex of the operator's brand colour for this line ("#E4002B").
    let lineColorHex: String
    /// Short line code displayed on the pill ("U1", "Central").
    let lineShortName: String
}

@MainActor
enum TransitRouteResolver {

    /// Returns a polyline path for `ticket` when it is a transit
    /// ticket whose endpoints both resolve onto a single line in a
    /// bundled catalog. Returns nil for non-transit tickets, missing
    /// endpoints, or cities we don't ship a catalog for.
    static func resolve(for ticket: Ticket) -> TransitRoutePath? {
        guard
            let underground = transitPayload(ticket.payload),
            let origin = ticket.originLocation,
            let destination = ticket.destinationLocation
        else { return nil }

        let cityHint = origin.city ?? destination.city ?? ""
        guard
            !cityHint.isEmpty,
            let catalog = TransitCatalogLoader.catalog(forCityHint: cityHint),
            let line = matchLine(
                shortName: underground.lineShortName,
                longName: underground.lineName,
                in: catalog
            )
        else { return nil }

        guard
            let originIdx = stationIndex(
                in: line, name: origin.name, coord: origin.coordinate
            ),
            let destIdx = stationIndex(
                in: line, name: destination.name, coord: destination.coordinate
            ),
            originIdx != destIdx
        else { return nil }

        // Re-order the line's stations into a geographic chain. Some
        // sources (e.g. London's TfL Line API) ship stations in
        // arbitrary order rather than GTFS `stop_sequence`, so slicing
        // the raw `[lo...hi]` would zigzag across the city. The chain
        // is cached per line id.
        let chain = Self.chainOrder(for: line)
        let chainPos = Self.chainPosition(for: line.id, chain: chain)
        guard
            let oP = chainPos[originIdx],
            let dP = chainPos[destIdx],
            oP != dP
        else { return nil }

        var pathStations = arc(in: line, chain: chain, from: oP, to: dP)
        // Loop detection: when the chain's first and last stations sit
        // close enough that they're adjacent on a real loop (Circle,
        // Yamanote), evaluate the wrap-around arc and pick whichever
        // is shorter.
        if Self.chainIsLoop(line: line, chain: chain) {
            let wrap = wrapArc(in: line, chain: chain, from: oP, to: dP)
            if pathLength(wrap) < pathLength(pathStations) {
                pathStations = wrap
            }
        }

        // Orient the path so the polyline reads origin → destination
        // visually, regardless of which end of the chain is "first".
        let originCoord = origin.coordinate
        if let head = pathStations.first, let tail = pathStations.last {
            let dHead = haversineMeters(
                lat1: originCoord.latitude, lng1: originCoord.longitude,
                lat2: head.lat, lng2: head.lng
            )
            let dTail = haversineMeters(
                lat1: originCoord.latitude, lng1: originCoord.longitude,
                lat2: tail.lat, lng2: tail.lng
            )
            if dHead > dTail { pathStations.reverse() }
        }

        let coords = pathStations.map { station in
            CLLocationCoordinate2D(latitude: station.lat, longitude: station.lng)
        }
        return TransitRoutePath(
            origin: origin,
            destination: destination,
            coordinates: coords,
            lineColorHex: line.color,
            lineShortName: line.shortName
        )
    }

    // MARK: - Chain reordering

    /// Permutation of `line.stations` indices in geographic order,
    /// produced by greedy nearest-neighbour starting from a corner of
    /// the bounding box. Cached per `line.id`.
    private static var chainCache: [String: [Int]] = [:]
    private static var chainPositionCache: [String: [Int: Int]] = [:]
    private static var loopCache: [String: Bool] = [:]

    private static func chainOrder(for line: TransitLine) -> [Int] {
        if let cached = chainCache[line.id] { return cached }
        let stations = line.stations
        let n = stations.count
        guard n > 1 else {
            chainCache[line.id] = Array(0..<n)
            return Array(0..<n)
        }

        // Start from the station with the smallest (lat + lng) — a
        // corner of the bounding box. For roughly-linear lines this
        // is reliably an endpoint, not a midpoint.
        var start = 0
        var minSum = Double.infinity
        for (i, s) in stations.enumerated() {
            let v = s.lat + s.lng
            if v < minSum { minSum = v; start = i }
        }

        var visited = Array(repeating: false, count: n)
        var chain: [Int] = [start]
        visited[start] = true
        while chain.count < n {
            let cur = stations[chain.last!]
            var bestIdx = -1
            var bestD = Double.infinity
            for j in 0..<n where !visited[j] {
                let d = haversineMeters(
                    lat1: cur.lat, lng1: cur.lng,
                    lat2: stations[j].lat, lng2: stations[j].lng
                )
                if d < bestD { bestD = d; bestIdx = j }
            }
            if bestIdx < 0 { break }
            visited[bestIdx] = true
            chain.append(bestIdx)
        }
        chainCache[line.id] = chain
        return chain
    }

    private static func chainPosition(
        for lineId: String,
        chain: [Int]
    ) -> [Int: Int] {
        if let cached = chainPositionCache[lineId] { return cached }
        var out: [Int: Int] = [:]
        for (pos, idx) in chain.enumerated() { out[idx] = pos }
        chainPositionCache[lineId] = out
        return out
    }

    /// True when the chain's two endpoints sit closer than ~2× the
    /// median segment length — meaning the line is almost certainly a
    /// closed loop (Circle, Yamanote) and the rider can travel either
    /// direction around it.
    private static func chainIsLoop(line: TransitLine, chain: [Int]) -> Bool {
        if let cached = loopCache[line.id] { return cached }
        guard chain.count >= 4 else {
            loopCache[line.id] = false
            return false
        }
        let stations = line.stations
        var segments: [Double] = []
        segments.reserveCapacity(chain.count - 1)
        for i in 1..<chain.count {
            let a = stations[chain[i - 1]]
            let b = stations[chain[i]]
            segments.append(haversineMeters(
                lat1: a.lat, lng1: a.lng, lat2: b.lat, lng2: b.lng
            ))
        }
        segments.sort()
        let median = segments[segments.count / 2]
        let first = stations[chain.first!]
        let last  = stations[chain.last!]
        let endGap = haversineMeters(
            lat1: first.lat, lng1: first.lng,
            lat2: last.lat,  lng2: last.lng
        )
        let isLoop = endGap < median * 2.0
        loopCache[line.id] = isLoop
        return isLoop
    }

    private static func arc(
        in line: TransitLine,
        chain: [Int],
        from a: Int,
        to b: Int
    ) -> [TransitStation] {
        let lo = min(a, b)
        let hi = max(a, b)
        return chain[lo...hi].map { line.stations[$0] }
    }

    private static func wrapArc(
        in line: TransitLine,
        chain: [Int],
        from a: Int,
        to b: Int
    ) -> [TransitStation] {
        let lo = min(a, b)
        let hi = max(a, b)
        var out: [TransitStation] = []
        out.append(contentsOf: chain[hi...].map { line.stations[$0] })
        out.append(contentsOf: chain[...lo].map { line.stations[$0] })
        return out
    }

    private static func pathLength(_ stations: [TransitStation]) -> Double {
        guard stations.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1..<stations.count {
            let a = stations[i - 1]
            let b = stations[i]
            total += haversineMeters(
                lat1: a.lat, lng1: a.lng, lat2: b.lat, lng2: b.lng
            )
        }
        return total
    }

    // MARK: - Helpers

    private static func transitPayload(_ payload: TicketPayload) -> UndergroundTicket? {
        switch payload {
        case .underground(let v), .sign(let v), .infoscreen(let v), .grid(let v):
            return v
        default:
            return nil
        }
    }

    /// Resolves `lineShortName` against the catalog. Tries exact id /
    /// shortName match first, then case-insensitive, then long-name as
    /// a last resort.
    private static func matchLine(
        shortName: String,
        longName: String,
        in catalog: TransitCatalog
    ) -> TransitLine? {
        if let exact = catalog.lines.first(where: {
            $0.shortName == shortName || $0.id == shortName
        }) {
            return exact
        }
        let trimmed = shortName.trimmingCharacters(in: .whitespaces).lowercased()
        if !trimmed.isEmpty,
           let ci = catalog.lines.first(where: {
               $0.shortName.lowercased() == trimmed
                   || $0.id.lowercased() == trimmed
           }) {
            return ci
        }
        return catalog.lines.first { $0.longName == longName }
    }

    /// Index of `name` on `line`, preferring the catalog's transfer-key
    /// match and falling back to the closest station within `maxMeters`
    /// of `coord` — the same dual strategy `TransitCatalog.resolveStation`
    /// uses, scoped to a single line.
    private static func stationIndex(
        in line: TransitLine,
        name: String,
        coord: CLLocationCoordinate2D,
        maxMeters: Double = 500
    ) -> Int? {
        let key = TransitCatalog.transferKey(name)
        if let idx = line.stations.firstIndex(where: {
            TransitCatalog.transferKey($0.name) == key
        }) {
            return idx
        }
        var best: (idx: Int, distance: Double)?
        for (idx, station) in line.stations.enumerated() {
            let d = haversineMeters(
                lat1: coord.latitude, lng1: coord.longitude,
                lat2: station.lat, lng2: station.lng
            )
            if d <= maxMeters, best == nil || d < best!.distance {
                best = (idx, d)
            }
        }
        return best?.idx
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
        let a = sin(dLat / 2) * sin(dLat / 2)
            + sin(dLng / 2) * sin(dLng / 2) * cos(l1) * cos(l2)
        return 2 * r * asin(min(1, sqrt(a)))
    }
}
