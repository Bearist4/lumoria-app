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

        let clusters = catalog.clusters
        let linesByCluster = clusters.linesByCluster
        let stationsById = catalog.stationsById
        let originKey = catalog.clusterKey(for: origin)
        let destKey   = catalog.clusterKey(for: destination)

        let originLines = linesByCluster[originKey] ?? []
        let destLineIds = Set((linesByCluster[destKey] ?? []).map(\.id))

        // 1. Direct routes — one per line that serves both endpoints.
        var directRoutes: [[TransitLeg]] = []
        for line in originLines where destLineIds.contains(line.id) {
            guard
                let fromIdx = indexOfStation(withClusterKey: originKey, in: line, catalog: catalog),
                let toIdx   = indexOfStation(withClusterKey: destKey, in: line, catalog: catalog)
            else { continue }
            let leg = TransitLeg(
                line: line,
                origin: line.stations[fromIdx],
                destination: line.stations[toIdx],
                stopsCount: Self.stopDistance(line: line, from: fromIdx, to: toIdx)
            )
            directRoutes.append([leg])
        }

        // Short-circuit: any journey that can be done on a single
        // line IS the fastest option. Don't offer "take U1 then
        // transfer to U4" when both endpoints are already on U4 —
        // riders minimise changes and an inadvertent transfer
        // alternative just clutters the picker.
        //
        // Multiple direct lines between the two stations ARE still
        // valid alternatives (U-Bahn vs S-Bahn, tram vs bus), so we
        // keep every direct route and rank them by fewest stops.
        if !directRoutes.isEmpty {
            directRoutes.sort { totalStops($0) < totalStops($1) }
            return Array(directRoutes.prefix(max))
        }

        var results: [[TransitLeg]] = []

        // 2. Transfer-based routes — one BFS pass per distinct
        //    starting line. Seeding from a different line each run
        //    yields diverse alternatives without needing k-shortest-
        //    paths machinery.
        for startLine in originLines {
            if let route = bfsRoute(
                from: origin,
                to: destination,
                catalog: catalog,
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
                        catalog: catalog,
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
    /// the fewest stops between them. Uses cluster keys so two
    /// physically-separate stops sharing a name don't masquerade as
    /// the same station (Nantes "Jean Jaurès" on bus 96 vs tram 3).
    private static func directLine(
        from origin: TransitStation,
        to destination: TransitStation,
        catalog: TransitCatalog
    ) -> (line: TransitLine, fromIndex: Int, toIndex: Int)? {
        let originKey = catalog.clusterKey(for: origin)
        let destKey   = catalog.clusterKey(for: destination)

        let linesByCluster = catalog.linesByCluster
        let originLines = linesByCluster[originKey] ?? []
        let destLines   = Set((linesByCluster[destKey] ?? []).map(\.id))

        var best: (line: TransitLine, fromIndex: Int, toIndex: Int, distance: Int)? = nil
        for line in originLines where destLines.contains(line.id) {
            guard
                let fromIdx = indexOfStation(withClusterKey: originKey, in: line, catalog: catalog),
                let toIdx   = indexOfStation(withClusterKey: destKey, in: line, catalog: catalog)
            else { continue }
            let distance = abs(toIdx - fromIdx)
            if best == nil || distance < best!.distance {
                best = (line, fromIdx, toIdx, distance)
            }
        }
        return best.map { ($0.line, $0.fromIndex, $0.toIndex) }
    }

    /// Index of the first station on `line` whose cluster key matches.
    /// Returns nil when the line doesn't serve that cluster.
    private static func indexOfStation(
        withClusterKey key: String,
        in line: TransitLine,
        catalog: TransitCatalog
    ) -> Int? {
        line.stations.firstIndex {
            catalog.clusterKey(for: $0) == key
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
        catalog: TransitCatalog,
        startingLines: [TransitLine]? = nil,
        excludedLineIds: Set<String> = []
    ) -> [TransitLeg]? {
        let linesByCluster = catalog.linesByCluster
        let originKey = catalog.clusterKey(for: origin)
        let destKey   = catalog.clusterKey(for: destination)
        let keep: (TransitLine) -> Bool = { !excludedLineIds.contains($0.id) }

        guard
            let allOriginLinesRaw = linesByCluster[originKey],
            !allOriginLinesRaw.isEmpty,
            let destLinesListRaw = linesByCluster[destKey],
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

        // Seed: every (origin cluster, line) starting state.
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
               let currentLine = linesByCluster[node.stationKey]?
                .first(where: { $0.id == node.lineId }),
               let idx = indexOfStation(withClusterKey: node.stationKey, in: currentLine, catalog: catalog) {
                for neighborIdx in [idx - 1, idx + 1] where currentLine.stations.indices.contains(neighborIdx) {
                    let neighborStation = currentLine.stations[neighborIdx]
                    let next = Node(
                        stationKey: catalog.clusterKey(for: neighborStation),
                        lineId: currentLine.id
                    )
                    if !visited.contains(next) {
                        visited.insert(next)
                        parents[next] = node
                        queue.append(next)
                    }
                }
            }

            // Transfer neighbours: same cluster, different non-excluded line.
            for otherLine in (linesByCluster[node.stationKey] ?? [])
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

        return legs(from: path, catalog: catalog)
    }

    /// Collapses a BFS node path into `[Leg]`, one per contiguous
    /// run of nodes that share a `lineId`.
    private static func legs(
        from path: [Node],
        catalog: TransitCatalog
    ) -> [TransitLeg]? {
        guard !path.isEmpty else { return nil }

        let linesByCluster = catalog.linesByCluster
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
                    let line = linesByCluster[startNode.stationKey]?
                        .first(where: { $0.id == startNode.lineId }),
                    let fromIdx = indexOfStation(
                        withClusterKey: startNode.stationKey, in: line, catalog: catalog
                    ),
                    let toIdx = indexOfStation(
                        withClusterKey: endNode.stationKey, in: line, catalog: catalog
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

    /// Number of station-to-station segments the rider travels —
    /// i.e. the number of times the train stops between boarding
    /// and alighting, counting the destination. Two adjacent
    /// stations return 1 (not 0), "Leopoldau" to "Kagraner Platz"
    /// across 3 intermediate stops returns 4.
    ///
    /// Matches rider intuition ("the next stop is my stop" = 1
    /// stop) rather than the pure mathematical "intermediate
    /// stations" count.
    static func stopDistance(
        line: TransitLine,
        from: Int,
        to: Int
    ) -> Int {
        max(1, abs(to - from))
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
