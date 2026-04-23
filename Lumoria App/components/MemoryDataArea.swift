//
//  MemoryDataArea.swift
//  Lumoria App
//
//  Floating card rendered at the bottom of `MemoryMapView`. Computes and
//  displays four journey-level stats in a 2×2 grid: total ticket count,
//  day span, unique category count, and total traveled distance (km).
//  Mirrors the Journey Wrap stats described in the map story-mode spec.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1841-39662
//

import CoreLocation
import SwiftUI

struct MemoryDataArea: View {

    let memory: Memory
    let tickets: [Ticket]
    let anchors: [JourneyAnchor]

    @AppStorage("map.distanceUnit") private var distanceUnitRaw: String = MapDistanceUnit.km.rawValue

    init(
        memory: Memory,
        tickets: [Ticket],
        anchors: [JourneyAnchor] = []
    ) {
        self.memory = memory
        self.tickets = tickets
        self.anchors = anchors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grid
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                bottomLeadingRadius: 44,
                bottomTrailingRadius: 44,
                topTrailingRadius: 32,
                style: .continuous
            )
            .fill(Color.Background.default)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8),
                      GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            LumoriaNumberedData(value: ticketCount, label: "Tickets")
            LumoriaNumberedData(value: daySpan,     label: "Days")
            LumoriaNumberedData(value: categoryCount, label: "Categories")
            LumoriaNumberedData(value: distanceValue, label: distanceLabel)
        }
    }

    private var unit: MapDistanceUnit {
        MapDistanceUnit(rawValue: distanceUnitRaw) ?? .km
    }

    private var distanceLabel: LocalizedStringKey {
        unit == .mi ? "Miles" : "Kilometers"
    }

    // MARK: - Stats

    private var ticketCount: Int { tickets.count }

    /// Inclusive day count between `memory.startDate` and `memory.endDate`
    /// when both are set. Otherwise falls back to the span between the
    /// earliest and latest ticket `createdAt`.
    private var daySpan: Int {
        let cal = Calendar.current
        let range: (start: Date, end: Date)
        if let s = memory.startDate, let e = memory.endDate, s <= e {
            range = (s, e)
        } else {
            let dates = tickets.map(\.createdAt)
            guard let min = dates.min(), let max = dates.max() else { return 0 }
            range = (min, max)
        }
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: range.start),
            to: cal.startOfDay(for: range.end)
        ).day ?? 0
        return max(1, days + 1)
    }

    private var categoryCount: Int {
        Set(tickets.map { $0.kind.categoryStyle }).count
    }

    /// Total journey distance formatted in the user's preferred unit.
    /// Values are derived from the Haversine-in-kilometers total and
    /// converted when the unit preference is miles.
    private var distanceValue: String {
        let km = Self.totalDistanceKm(tickets: tickets, anchors: anchors)
        let value = unit.format(km: km)
        if value == 0 { return "0" }
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    // MARK: - Distance math

    /// Total Haversine distance across the journey. Every ticket
    /// contributes its origin then its destination (or just its one
    /// location for single-venue tickets); anchors slot in by date.
    /// Distance is the straight-line sum between each consecutive pair of
    /// stops across the entire chronological sequence — both the legs
    /// within a ticket and the transitions between tickets count.
    static func totalDistanceKm(
        tickets: [Ticket],
        anchors: [JourneyAnchor]
    ) -> Double {
        struct Stop { let date: Date; let coord: CLLocationCoordinate2D }

        var stops: [Stop] = []
        for t in tickets {
            if let o = t.originLocation?.coordinate {
                stops.append(Stop(date: t.createdAt, coord: o))
            }
            if let d = t.destinationLocation?.coordinate {
                stops.append(Stop(date: t.createdAt, coord: d))
            }
        }
        for a in anchors {
            stops.append(Stop(date: a.date, coord: a.coordinate))
        }

        stops.sort { $0.date < $1.date }
        guard stops.count > 1 else { return 0 }

        var km: Double = 0
        for i in 1..<stops.count {
            km += haversineKm(stops[i - 1].coord, stops[i].coord)
        }
        return km
    }

    private static func haversineKm(
        _ a: CLLocationCoordinate2D,
        _ b: CLLocationCoordinate2D
    ) -> Double {
        let r = 6371.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLng = (b.longitude - a.longitude) * .pi / 180
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180

        let h = sin(dLat / 2) * sin(dLat / 2)
              + sin(dLng / 2) * sin(dLng / 2) * cos(lat1) * cos(lat2)
        return 2 * r * asin(min(1, sqrt(h)))
    }
}

// MARK: - Preview

#Preview("DataArea") {
    let memory = Memory(
        id: UUID(),
        userId: UUID(),
        name: "Paris 2026",
        colorFamily: "Pink",
        emoji: "🗼",
        startDate: nil,
        endDate: nil,
        createdAt: .now,
        updatedAt: .now
    )
    return MemoryDataArea(
        memory: memory,
        tickets: [],
        anchors: []
    )
    .padding()
    .background(Color.gray.opacity(0.2))
}
