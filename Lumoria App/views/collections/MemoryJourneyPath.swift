//
//  MemoryJourneyPath.swift
//  Lumoria App
//
//  Shared helper that turns an ordered list of stop coordinates into a
//  smoothly curved polyline suitable for `MapPolyline` and for the
//  exported snapshot. Each leg (A → B) is sampled from a quadratic
//  Bezier curve whose control point sits perpendicular to the A→B line,
//  offset by a fraction of the leg length. Gives the map route a soft
//  arc between stops instead of straight dotted segments.
//

import CoreLocation
import Foundation

enum MemoryJourneyPath {

    /// Number of intermediate points sampled per leg. Higher = smoother
    /// curve, heavier render. 32 is enough that the curve reads round at
    /// typical zoom levels without bloating the MapPolyline coordinate
    /// buffer for long journeys.
    private static let samplesPerLeg = 32

    /// How far the Bezier control point sits off the midpoint of each
    /// leg, as a fraction of leg length. 0.22 gives a gentle arc; larger
    /// values produce more pronounced humps.
    private static let curvature: Double = 0.22

    /// Expands a chronological list of stop coordinates into a curved
    /// polyline. Consecutive duplicates are dropped before curving so a
    /// cluster pin doesn't produce a zero-length leg.
    static func curved(_ stops: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        let cleaned = dedup(stops)
        guard cleaned.count > 1 else { return cleaned }

        var out: [CLLocationCoordinate2D] = []
        for i in 0..<cleaned.count - 1 {
            let leg = bezier(
                from: cleaned[i],
                to:   cleaned[i + 1],
                samples: samplesPerLeg,
                alternate: i % 2 == 1
            )
            // Skip the first point of every leg after the first so
            // adjacent legs join seamlessly without duplicate vertices.
            out.append(contentsOf: i == 0 ? leg : Array(leg.dropFirst()))
        }
        return out
    }

    // MARK: - Dedup

    private static func dedup(_ coords: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        var out: [CLLocationCoordinate2D] = []
        for c in coords {
            if let last = out.last,
               abs(last.latitude  - c.latitude)  < 1e-5,
               abs(last.longitude - c.longitude) < 1e-5 {
                continue
            }
            out.append(c)
        }
        return out
    }

    // MARK: - Bezier

    /// Samples a quadratic Bezier from `a` to `b` with a control point
    /// perpendicular to the AB line. Alternating the sign of the offset
    /// between legs keeps a long journey from curving consistently to one
    /// side and helps the route read like a natural travel line.
    private static func bezier(
        from a: CLLocationCoordinate2D,
        to b: CLLocationCoordinate2D,
        samples: Int,
        alternate: Bool
    ) -> [CLLocationCoordinate2D] {
        let dx = b.longitude - a.longitude
        let dy = b.latitude  - a.latitude
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return [a, b] }

        // Right-hand normal in lat/lng space.
        let nLat =  dx / length
        let nLng = -dy / length
        let sign: Double = alternate ? -1 : 1
        let offset = length * curvature * sign

        let ctrlLat = (a.latitude  + b.latitude)  / 2 + nLat * offset
        let ctrlLng = (a.longitude + b.longitude) / 2 + nLng * offset

        var out: [CLLocationCoordinate2D] = []
        out.reserveCapacity(samples + 1)
        for i in 0...samples {
            let t = Double(i) / Double(samples)
            let u = 1 - t
            let lat = u * u * a.latitude  + 2 * u * t * ctrlLat + t * t * b.latitude
            let lng = u * u * a.longitude + 2 * u * t * ctrlLng + t * t * b.longitude
            out.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        return out
    }
}
