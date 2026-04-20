//
//  MemoryMapView.swift
//  Lumoria App
//
//  Full-screen map that plots every ticket in a memory at its stored
//  origin/destination locations. Pins that share the exact same coordinate
//  are merged into a single cluster pin that shows the ticket count and a
//  pie-chart of per-ticket category colors. Tapping a single-ticket pin
//  opens that ticket's detail; tapping a cluster opens a bottom sheet
//  listing every ticket at that location.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1652-47256
//

import CoreLocation
import MapKit
import SwiftUI

struct MemoryMapView: View {
    @Environment(\.dismiss) private var dismiss

    let memory: Memory
    let tickets: [Ticket]

    @State private var camera: MapCameraPosition
    @State private var selectedTicket: Ticket?
    @State private var selectedGroup: GroupedPin?

    init(memory: Memory, tickets: [Ticket]) {
        self.memory = memory
        self.tickets = tickets
        _camera = State(initialValue: Self.initialCamera(for: tickets))
    }

    // MARK: - Body

    var body: some View {
        Map(position: $camera) {
            ForEach(groupedPins) { group in
                Annotation("", coordinate: group.coordinate, anchor: .bottom) {
                    Button {
                        handleTap(group)
                    } label: {
                        TicketMapPin(categories: group.items.map {
                            $0.ticket.kind.categoryStyle
                        })
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .all))
        .ignoresSafeArea()
        .onAppear {
            Analytics.track(.mapOpened(
                memoryIdHash: AnalyticsIdentity.hashUUID(memory.id),
                pinCount: groupedPins.count,
                ticketCount: tickets.count
            ))
        }
        .overlay(alignment: .topLeading) {
            LumoriaIconButton(
                systemImage: "chevron.left",
                size: .large,
                position: .onSurface,
                action: { dismiss() }
            )
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .sheet(item: $selectedTicket) { ticket in
            NavigationStack {
                TicketDetailView(ticket: ticket, openedFromSource: .memory)
            }
        }
        .sheet(item: $selectedGroup) { group in
            NavigationStack {
                PinTicketsSheet(group: group) { ticket in
                    selectedGroup = nil
                    // Defer so the dismiss animation starts before the next
                    // sheet presentation (avoids a visual pop).
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        selectedTicket = ticket
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Tap handling

    private func handleTap(_ group: GroupedPin) {
        for item in group.items {
            Analytics.track(.mapPinTapped(
                category: item.ticket.kind.analyticsCategory,
                template: item.ticket.kind.analyticsTemplate,
                pinType: item.pinType
            ))
        }

        if group.items.count == 1, let only = group.items.first {
            selectedTicket = only.ticket
        } else {
            selectedGroup = group
        }
    }

    // MARK: - Annotations

    fileprivate struct PinAnnotation: Identifiable, Hashable {
        let id: String
        let ticket: Ticket
        let location: TicketLocation
        let pinType: MapPinTypeProp

        var coordinate: CLLocationCoordinate2D { location.coordinate }

        static func == (lhs: PinAnnotation, rhs: PinAnnotation) -> Bool {
            lhs.id == rhs.id
        }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    /// Tickets that share the same coordinate collapse into one pin.
    fileprivate struct GroupedPin: Identifiable, Hashable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let items: [PinAnnotation]

        /// Primary label for the sheet header — the `name` of the location
        /// on the first ticket at this pin. All items share the same
        /// coordinate, so the first is representative.
        var headerName: String { items.first?.location.name ?? "" }

        static func == (lhs: GroupedPin, rhs: GroupedPin) -> Bool {
            lhs.id == rhs.id
        }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    /// One annotation per ticket-location pairing. A plane ticket with both
    /// airports filled contributes two pins; a single-venue ticket one.
    private var annotations: [PinAnnotation] {
        tickets.flatMap { ticket -> [PinAnnotation] in
            var out: [PinAnnotation] = []
            if let origin = ticket.originLocation {
                out.append(.init(
                    id: "\(ticket.id.uuidString)-origin",
                    ticket: ticket,
                    location: origin,
                    pinType: .origin
                ))
            }
            if let destination = ticket.destinationLocation {
                out.append(.init(
                    id: "\(ticket.id.uuidString)-destination",
                    ticket: ticket,
                    location: destination,
                    pinType: .destination
                ))
            }
            return out
        }
    }

    /// Groups `annotations` by rounded coordinate (~1m precision). Order of
    /// groups and their items is preserved from `tickets` so the pie-slice
    /// layout is stable across re-renders.
    private var groupedPins: [GroupedPin] {
        var order: [String] = []
        var buckets: [String: [PinAnnotation]] = [:]

        for a in annotations {
            let key = Self.coordinateKey(a.coordinate)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(a)
        }

        return order.compactMap { key in
            guard let items = buckets[key], let first = items.first else { return nil }
            return GroupedPin(id: key, coordinate: first.coordinate, items: items)
        }
    }

    private static func coordinateKey(_ c: CLLocationCoordinate2D) -> String {
        String(format: "%.5f_%.5f", c.latitude, c.longitude)
    }

    // MARK: - Camera

    /// Fits the initial camera around every pin this memory will display.
    /// Falls back to a default region when the memory has no located tickets
    /// (e.g. the user opened the map before attaching any).
    private static func initialCamera(for tickets: [Ticket]) -> MapCameraPosition {
        let coords: [CLLocationCoordinate2D] = tickets.flatMap { t in
            [t.originLocation?.coordinate, t.destinationLocation?.coordinate]
                .compactMap { $0 }
        }

        guard let first = coords.first else {
            return .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
            ))
        }

        guard coords.count > 1 else {
            return .region(MKCoordinateRegion(
                center: first,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
        }

        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        // 1.6× padding so pins don't sit on the screen edge.
        let span = MKCoordinateSpan(
            latitudeDelta:  max(0.5, (lats.max()! - lats.min()!) * 1.6),
            longitudeDelta: max(0.5, (lngs.max()! - lngs.min()!) * 1.6)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }
}

// MARK: - Pin bottom sheet

/// Sheet listing the tickets that share a single map pin. Each row hands
/// the tapped ticket back via `onSelect` so the parent view can route to
/// `TicketDetailView`.
private struct PinTicketsSheet: View {
    let group: MemoryMapView.GroupedPin
    let onSelect: (Ticket) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                VStack(spacing: 0) {
                    ForEach(group.items) { item in
                        Button {
                            onSelect(item.ticket)
                        } label: {
                            row(for: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.Background.default)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.headerName)
                .font(.title2.bold())
                .foregroundStyle(Color.Text.primary)
                .lineLimit(2)

            Text(pinCountLabel)
                .font(.subheadline)
                .foregroundStyle(Color.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private var pinCountLabel: String {
        let count = group.items.count
        return count == 1
            ? String(localized: "1 ticket on this pin")
            : String(localized: "\(count) tickets on this pin")
    }

    private func row(for item: MemoryMapView.PinAnnotation) -> some View {
        let category = item.ticket.kind.categoryStyle
        return LumoriaListItem(
            title: item.ticket.kind.categoryLabel,
            subtitle: routeSubtitle(item.ticket),
            leftItem: {
                ZStack {
                    Circle().fill(category.backgroundColor)
                    Image(systemName: category.systemImage)
                        .font(.title3)
                        .foregroundStyle(category.onColor)
                }
            },
            rightItem: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.Text.tertiary)
            }
        )
    }

    private func routeSubtitle(_ ticket: Ticket) -> String? {
        let origin = ticket.originLocation
        let dest = ticket.destinationLocation

        if let o = origin, let d = dest {
            return "\(o.subtitle ?? o.name) → \(d.subtitle ?? d.name)"
        }
        return origin?.name ?? dest?.name
    }
}

// MARK: - Preview helpers

private func previewMemory() -> Memory {
    Memory(
        id: UUID(), userId: UUID(),
        name: "Japan 2026", colorFamily: "Red", emoji: "🗾",
        createdAt: .now, updatedAt: .now
    )
}

private let previewHaneda = TicketLocation(
    name: "Tokyo Haneda", subtitle: "HND",
    city: "Tokyo", country: "Japan", countryCode: "JP",
    lat: 35.5494, lng: 139.7798, kind: .airport
)

private let previewNarita = TicketLocation(
    name: "Tokyo Narita", subtitle: "NRT",
    city: "Tokyo", country: "Japan", countryCode: "JP",
    lat: 35.7720, lng: 140.3929, kind: .airport
)

/// Builds a plane ticket pinned at `location`, tagged into `memoryId`.
/// Uses the shared PrismTicket sample so the list rows have real data.
private func previewPlaneTicket(
    at location: TicketLocation,
    memoryId: UUID
) -> Ticket {
    let base = TicketsStore.sampleTickets[0]
    return Ticket(
        id: UUID(),
        orientation: base.orientation,
        payload: base.payload,
        memoryIds: [memoryId],
        originLocation: location
    )
}

/// Builds a train ticket at `location`. Gives the cluster pin a second
/// color (Yellow) to make the pie slices visible in previews.
private func previewTrainTicket(
    at location: TicketLocation,
    memoryId: UUID
) -> Ticket {
    Ticket(
        orientation: .horizontal,
        payload: .express(ExpressTicket(
            trainType: "Shinkansen",
            trainNumber: "Hikari 503",
            cabinClass: "Green",
            originCity: "Tokyo",
            originCityKanji: "東京",
            destinationCity: "Osaka",
            destinationCityKanji: "大阪",
            date: "14.03.2026",
            departureTime: "06:33",
            arrivalTime: "09:10",
            car: "7",
            seat: "14A",
            ticketNumber: "0000000000"
        )),
        memoryIds: [memoryId],
        originLocation: location
    )
}

// MARK: - Previews

#Preview("1 ticket at location") {
    let memory = previewMemory()
    return MemoryMapView(
        memory: memory,
        tickets: [
            previewPlaneTicket(at: previewHaneda, memoryId: memory.id),
        ]
    )
    .environmentObject(TicketsStore())
    .environmentObject(MemoriesStore())
}

#Preview("2 tickets at same pin") {
    let memory = previewMemory()
    return MemoryMapView(
        memory: memory,
        tickets: [
            previewPlaneTicket(at: previewHaneda, memoryId: memory.id),
            previewTrainTicket(at: previewHaneda, memoryId: memory.id),
        ]
    )
    .environmentObject(TicketsStore())
    .environmentObject(MemoriesStore())
}

#Preview("3 tickets at same pin") {
    let memory = previewMemory()
    return MemoryMapView(
        memory: memory,
        tickets: [
            previewPlaneTicket(at: previewHaneda, memoryId: memory.id),
            previewTrainTicket(at: previewHaneda, memoryId: memory.id),
            previewPlaneTicket(at: previewHaneda, memoryId: memory.id),
        ]
    )
    .environmentObject(TicketsStore())
    .environmentObject(MemoriesStore())
}

#Preview("4 tickets at same pin") {
    let memory = previewMemory()
    return MemoryMapView(
        memory: memory,
        tickets: [
            previewPlaneTicket(at: previewHaneda, memoryId: memory.id),
            previewTrainTicket(at: previewHaneda, memoryId: memory.id),
            previewPlaneTicket(at: previewHaneda, memoryId: memory.id),
            previewTrainTicket(at: previewHaneda, memoryId: memory.id),
        ]
    )
    .environmentObject(TicketsStore())
    .environmentObject(MemoriesStore())
}

#Preview("Tokyo · 2 separate pins") {
    let memory = previewMemory()
    return MemoryMapView(
        memory: memory,
        tickets: [
            previewPlaneTicket(at: previewHaneda, memoryId: memory.id),
            previewPlaneTicket(at: previewNarita, memoryId: memory.id),
        ]
    )
    .environmentObject(TicketsStore())
    .environmentObject(MemoriesStore())
}
