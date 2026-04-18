//
//  MemoryMapView.swift
//  Lumoria App
//
//  Full-screen map that plots every ticket in a memory at its stored
//  origin/destination locations. Tapping a pin opens that ticket's detail
//  view as a sheet over the map.
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

    init(memory: Memory, tickets: [Ticket]) {
        self.memory = memory
        self.tickets = tickets
        _camera = State(initialValue: Self.initialCamera(for: tickets))
    }

    // MARK: - Body

    var body: some View {
        Map(position: $camera) {
            ForEach(annotations) { a in
                Annotation("", coordinate: a.coordinate, anchor: .bottom) {
                    Button {
                        Analytics.track(.mapPinTapped(
                            category: a.ticket.kind.analyticsCategory,
                            template: a.ticket.kind.analyticsTemplate,
                            pinType: a.pinType
                        ))
                        selectedTicket = a.ticket
                    } label: {
                        TicketMapPin(category: a.ticket.kind.categoryStyle)
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
                pinCount: annotations.count,
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
    }

    // MARK: - Annotations

    private struct PinAnnotation: Identifiable {
        let id: String
        let ticket: Ticket
        let coordinate: CLLocationCoordinate2D
        let pinType: MapPinTypeProp
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
                    coordinate: origin.coordinate,
                    pinType: .origin
                ))
            }
            if let destination = ticket.destinationLocation {
                out.append(.init(
                    id: "\(ticket.id.uuidString)-destination",
                    ticket: ticket,
                    coordinate: destination.coordinate,
                    pinType: .destination
                ))
            }
            return out
        }
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

// MARK: - Preview

#Preview("Tokyo · 2 tickets") {
    let memory = Memory(
        id: UUID(), userId: UUID(),
        name: "Japan 2026", colorFamily: "Red", emoji: "🗾",
        createdAt: .now, updatedAt: .now
    )

    let haneda = TicketLocation(
        name: "Tokyo Haneda", subtitle: "HND",
        city: "Tokyo", country: "Japan", countryCode: "JP",
        lat: 35.5494, lng: 139.7798, kind: .airport
    )
    let narita = TicketLocation(
        name: "Tokyo Narita", subtitle: "NRT",
        city: "Tokyo", country: "Japan", countryCode: "JP",
        lat: 35.7720, lng: 140.3929, kind: .airport
    )

    var ticketA = TicketsStore.sampleTickets[0]
    ticketA.originLocation = haneda
    ticketA.memoryIds = [memory.id]

    var ticketB = TicketsStore.sampleTickets[1]
    ticketB.originLocation = narita
    ticketB.memoryIds = [memory.id]

    return MemoryMapView(memory: memory, tickets: [ticketA, ticketB])
        .environmentObject(TicketsStore())
        .environmentObject(MemoriesStore())
}
