//
//  TransitRouter.swift
//  Lumoria App
//
//  Journey router that runs over a bundled `TransitCatalog`. Given
//  two stations, returns one `Leg` per line the rider has to be on
//  — so "Leopoldau → Karlsplatz" on U1 is a single leg, while
//  "Leopoldau → Kettenbrückengasse" returns two (U1 Leopoldau →
//  Karlsplatz, then U4 Karlsplatz → Kettenbrückengasse).
//
//  The funnel consumes `[Leg]` to emit one `UndergroundTicket` per
//  leg, each with the correct per-line colour, stop count, and
//  station pair. Re-running the router is the mechanism by which
//  the ticket preview stays in sync with whatever stations the
//  user has picked.
//
//  Algorithm: BFS on a line-change graph. Nodes are (station, line)
//  pairs so changing lines at an interchange costs one BFS hop; the
//  shortest path in hops is therefore the journey with the fewest
//  transfers. Ties broken by total stop count (prefer faster).
//

import Foundation

struct TransitLeg: Hashable {
    let line: TransitLine
    let origin: TransitStation
    let destination: TransitStation
    /// Number of rider-visible stops between `origin` and
    /// `destination`, inclusive of the endpoints' direct neighbours
    /// but exclusive of the endpoints themselves — the value printed
    /// on the ticket ("3 stops" between Stephansplatz and Karlsplatz).
    let stopsCount: Int
}

enum TransitRouter {

    /// Single-route entry point kept for callers that only need the
    /// best suggestion. New code should prefer `routes(...)` which
    /// returns multiple alternatives the UI can offer as tiles.
    static func route(
        from origin: TransitStation,
        to destination: TransitStation,
        in catalog: TransitCatalog
    ) -> [TransitLeg]? {
        routes(from: origin, to: destination, in: catalog, max: 1).first
    }

    /// Returns up to `max` alternative routes from `origin` to
    /// `destination`. Each route is an ordered list of legs; one
    /// `UndergroundTicket` per leg. Sorted by fewest transfers first
    /// (ties broken by total stops), so the first entry is the
    /// optimal route and subsequent entries are progressively
    /// different combinations — e.g. "subway only", "subway + bus
    /// transfer", "tram + subway". Returns `[]` when the catalog
    /// doesn't connect the two stations.
    static func routes(
        from origin: TransitStation,
        to destination: TransitStation,
        in catalog: TransitCatalog,
        max: Int = 4
    ) -> [[TransitLeg]] {
        guard origin.id != destination.id else { return [] }

        let linesByTransferKey = catalog.linesByTransferKey
        let stationsById = catalog.stationsById
        let originKey = TransitCatalog.transferKey(origin.name)
        let destKey   = TransitCatalog.transferKey(destination.name)

        let originLines = linesByTransferKey[originKey] ?? []
        let destLineIds = Set((linesByTransferKey[destKey] ?? []).map(\.id))

        var results: [[TransitLeg]] = []

        // 1. Direct routes — one per line that serves both endpoints.
        for line in originLines where destLineIds.contains(line.id) {
            guard
                let fromIdx = indexOfStation(withTransferKey: originKey, in: line),
                let toIdx   = indexOfStation(withTransferKey: destKey, in: line)
            else { continue }
            let leg = TransitLeg(
                line: line,
                origin: line.stations[fromIdx],
                destination: line.stations[toIdx],
                stopsCount: Self.stopDistance(line: line, from: fromIdx, to: toIdx)
            )
            results.append([leg])
        }

        // 2. Transfer-based routes — one BFS pass per distinct
        //    starting line. Seeding from a different line each run
        //    yields diverse alternatives without needing k-shortest-
        //    paths machinery.
        for startLine in originLines {
            if let route = bfsRoute(
                from: origin,
                to: destination,
                linesByTransferKey: linesByTransferKey,
                stationsById: stationsById,
                startingLines: [startLine]
            ),
               !results.contains(where: { signature($0) == signature(route) }) {
                results.append(route)
            }
        }

        // 3. Line-exclusion search. When the origin is served by one
        //    line (e.g. Oberlaa → U1 only), the previous pass yields
        //    exactly one route and the picker has nothing to pick.
        //    Re-run BFS excluding each line used in the best route so
        //    the router surfaces alternatives that transfer at a
        //    different station, use a different mid-line, or swap in
        //    a tram / bus segment. Iterate results already found so
        //    exclusion compounds naturally.
        var cursor = 0
        while cursor < results.count && results.count < max * 2 {
            let route = results[cursor]
            cursor += 1
            for leg in route {
                let excluded: Set<String> = [leg.line.id]
                guard
                    let alt = bfsRoute(
                        from: origin,
                        to: destination,
                        linesByTransferKey: linesByTransferKey,
                        stationsById: stationsById,
                        startingLines: nil,
                        excludedLineIds: excluded
                    ),
                    !results.contains(where: { signature($0) == signature(alt) })
                else { continue }
                results.append(alt)
            }
        }

        // Sort by fewest legs first, then fewest total stops.
        results.sort { a, b in
            if a.count != b.count { return a.count < b.count }
            return totalStops(a) < totalStops(b)
        }
        return Array(results.prefix(max))
    }

    /// Signature used to dedupe two routes that hit the same line
    /// sequence. "U1 (Leopoldau→Stephansplatz) · U3 (Stephansplatz→
    /// Neubaugasse)" collapses to one entry regardless of which BFS
    /// pass produced it.
    private static func signature(_ route: [TransitLeg]) -> String {
        route
            .map { "\($0.line.id):\($0.origin.id)>\($0.destination.id)" }
            .joined(separator: "|")
    }

    private static func totalStops(_ route: [TransitLeg]) -> Int {
        route.reduce(0) { $0 + $1.stopsCount }
    }

    // MARK: - Direct

    /// Picks a line serving both endpoints, preferring the one with
    /// the fewest stops between them. Uses name-based transfer keys
    /// because producers often ship a separate `stop_id` per line
    /// (Wiener Linien U1-Stephansplatz vs U3-Stephansplatz), which
    /// would otherwise hide the fact that a single line carries both
    /// endpoints.
    private static func directLine(
        from origin: TransitStation,
        to destination: TransitStation,
        linesByTransferKey: [String: [TransitLine]]
    ) -> (line: TransitLine, fromIndex: Int, toIndex: Int)? {
        let originKey = TransitCatalog.transferKey(origin.name)
        let destKey   = TransitCatalog.transferKey(destination.name)

        let originLines = linesByTransferKey[originKey] ?? []
        let destLines   = Set((linesByTransferKey[destKey] ?? []).map(\.id))

        var best: (line: TransitLine, fromIndex: Int, toIndex: Int, distance: Int)? = nil
        for line in originLines where destLines.contains(line.id) {
            guard
                let fromIdx = indexOfStation(withTransferKey: originKey, in: line),
                let toIdx   = indexOfStation(withTransferKey: destKey,   in: line)
            else { continue }
            let distance = abs(toIdx - fromIdx)
            if best == nil || distance < best!.distance {
                best = (line, fromIdx, toIdx, distance)
            }
        }
        return best.map { ($0.line, $0.fromIndex, $0.toIndex) }
    }

    /// Index of the first station whose normalized name matches
    /// `transferKey`. Returns nil when the line doesn't serve that
    /// station.
    private static func indexOfStation(
        withTransferKey key: String,
        in line: TransitLine
    ) -> Int? {
        line.stations.firstIndex {
            TransitCatalog.transferKey($0.name) == key
        }
    }

    // MARK: - BFS transfer search

    /// BFS over (station, line) states. Each state represents
    /// "standing on this line at this station". Neighbours are:
    ///   • adjacent stations on the same line (no transfer)
    ///   • same station on a different line (transfer, costs a hop
    ///     so the planner prefers fewer line changes)
    ///
    /// Hop cost makes the *number of legs* the primary optimiser.
    /// To break ties on leg count, we prefer the path with the
    /// fewest total stops — explored via a priority scan over the
    /// candidates that share the minimum leg count.
    /// BFS with optional line-seed constraint + optional line
    /// exclusion. `startingLines` constrains which lines can seed the
    /// frontier; `excludedLineIds` removes lines from the graph
    /// entirely so a second-pass search finds a different route
    /// through different interchanges or modes. Both nil = full
    /// optimal search (legacy behaviour).
    private static func bfsRoute(
        from origin: TransitStation,
        to destination: TransitStation,
        linesByTransferKey: [String: [TransitLine]],
        stationsById: [String: TransitStation],
        startingLines: [TransitLine]? = nil,
        excludedLineIds: Set<String> = []
    ) -> [TransitLeg]? {
        let originKey = TransitCatalog.transferKey(origin.name)
        let destKey   = TransitCatalog.transferKey(destination.name)
        let keep: (TransitLine) -> Bool = { !excludedLineIds.contains($0.id) }

        guard
            let allOriginLinesRaw = linesByTransferKey[originKey],
            !allOriginLinesRaw.isEmpty,
            let destLinesListRaw = linesByTransferKey[destKey],
            !destLinesListRaw.isEmpty
        else { return nil }
        let allOriginLines = allOriginLinesRaw.filter(keep)
        let destLinesList  = destLinesListRaw.filter(keep)
        guard !allOriginLines.isEmpty, !destLinesList.isEmpty else { return nil }
        let destLineIds = Set(destLinesList.map(\.id))

        let seedLines = (startingLines ?? allOriginLines).filter(keep)
        guard !seedLines.isEmpty else { return nil }

        var visited: Set<Node> = []
        var parents: [Node: Node] = [:]
        var queue: [Node] = []

        // Seed: every (origin transfer-key, line) starting state.
        for line in seedLines {
            let node = Node(stationKey: originKey, lineId: line.id)
            visited.insert(node)
            queue.append(node)
        }

        var found: Node? = nil
        var head = 0
        while head < queue.count {
            let node = queue[head]; head += 1
            if node.stationKey == destKey && destLineIds.contains(node.lineId) {
                found = node
                break
            }

            // Same-line neighbours: adjacent stations on this line.
            if !excludedLineIds.contains(node.lineId),
               let currentLine = linesByTransferKey[node.stationKey]?
                .first(where: { $0.id == node.lineId }),
               let idx = indexOfStation(withTransferKey: node.stationKey, in: currentLine) {
                for neighborIdx in [idx - 1, idx + 1] where currentLine.stations.indices.contains(neighborIdx) {
                    let neighborStation = currentLine.stations[neighborIdx]
                    let next = Node(
                        stationKey: TransitCatalog.transferKey(neighborStation.name),
                        lineId: currentLine.id
                    )
                    if !visited.contains(next) {
                        visited.insert(next)
                        parents[next] = node
                        queue.append(next)
                    }
                }
            }

            // Transfer neighbours: same station, different non-excluded line.
            for otherLine in (linesByTransferKey[node.stationKey] ?? [])
                where otherLine.id != node.lineId
                   && !excludedLineIds.contains(otherLine.id) {
                let next = Node(stationKey: node.stationKey, lineId: otherLine.id)
                if !visited.contains(next) {
                    visited.insert(next)
                    parents[next] = node
                    queue.append(next)
                }
            }
        }

        guard let endNode = found else { return nil }

        var path: [Node] = [endNode]
        var cursor = endNode
        while let parent = parents[cursor] {
            path.append(parent)
            cursor = parent
        }
        path.reverse()

        return legs(from: path, linesByTransferKey: linesByTransferKey)
    }

    /// Collapses a BFS node path into `[Leg]`, one per contiguous
    /// run of nodes that share a `lineId`.
    private static func legs(
        from path: [Node],
        linesByTransferKey: [String: [TransitLine]]
    ) -> [TransitLeg]? {
        guard !path.isEmpty else { return nil }

        var out: [TransitLeg] = []
        var runStart = 0
        for i in 1...path.count {
            let endOfRun = i == path.count || path[i].lineId != path[runStart].lineId
            if endOfRun {
                let startNode = path[runStart]
                let endNode   = path[i - 1]
                if startNode.stationKey == endNode.stationKey {
                    // A transfer-only run (single node at a transfer
                    // station) — skip.
                    runStart = i
                    continue
                }
                guard
                    let line = linesByTransferKey[startNode.stationKey]?
                        .first(where: { $0.id == startNode.lineId }),
                    let fromIdx = indexOfStation(
                        withTransferKey: startNode.stationKey, in: line
                    ),
                    let toIdx = indexOfStation(
                        withTransferKey: endNode.stationKey, in: line
                    )
                else {
                    return nil
                }
                out.append(TransitLeg(
                    line: line,
                    origin: line.stations[fromIdx],
                    destination: line.stations[toIdx],
                    stopsCount: Self.stopDistance(line: line, from: fromIdx, to: toIdx)
                ))
                runStart = i
            }
        }
        return out
    }

    // MARK: - Stop-count helper

    /// Number of stations the rider visits between `from` and `to`
    /// on the same line, exclusive of both endpoints. "Leopoldau"
    /// to "Kagraner Platz" separated by 3 intermediate stops
    /// returns 3.
    static func stopDistance(
        line: TransitLine,
        from: Int,
        to: Int
    ) -> Int {
        max(0, abs(to - from) - 1)
    }
}

// MARK: - Shorthand for BFS node (private in router)

extension TransitRouter {
    /// BFS state: "standing on this line at the station with this
    /// transfer key". Using the name-derived transfer key means
    /// platforms that share a station but have distinct `stop_id`s
    /// (Wiener Linien) still collapse into a single transfer node.
    fileprivate struct Node: Hashable {
        let stationKey: String
        let lineId: String
    }
}
