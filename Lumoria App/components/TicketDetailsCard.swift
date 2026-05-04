//
//  TicketDetailsCard.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1016-21315
//
//  Surface shown in the ticket-detail view. Stacks:
//    • Title ("About this ticket")
//    • Creation + Last edit — two half-width metadata cards
//    • Category tile — full-width colored pill for the ticket's category
//    • Location card (optional) — compact map with a white pill labeling
//      the primary location at the bottom
//    • Memories section — header + overflow menu + caller-supplied content
//

import MapKit
import SwiftUI

// MARK: - Card

struct TicketDetailsCard<MemoriesContent: View>: View {

    // MARK: Inputs

    var title: LocalizedStringKey = "About this ticket"
    let creationDate: String
    let lastEditDate: String
    let category: TicketCategoryStyle
    /// Primary location of the ticket. Hidden when nil. Ignored when
    /// `transitRoute` is non-nil — that overrides the single-pin map
    /// with a two-pin + polyline rendering.
    let location: TicketLocation?
    /// Resolved transit polyline with both endpoints. When set, the
    /// card draws origin + destination markers and a colored line
    /// along the catalog's stations between them.
    var transitRoute: TransitRoutePath? = nil
    var memoriesTitle: LocalizedStringKey = "Memories"
    let menuItems: [LumoriaMenuItem]
    @ViewBuilder var memoriesContent: () -> MemoriesContent

    // MARK: Camera state
    //
    // `Map(initialPosition:)` only reads its argument once at mount,
    // so the camera froze on the first leg when used inside a paged
    // detail view. Holding the position in state and re-issuing it on
    // location/route change keeps the camera in sync as the focused
    // leg switches under the card.

    @State private var locationCamera: MapCameraPosition = .automatic
    @State private var routeCamera: MapCameraPosition = .automatic

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title.bold())
                .foregroundStyle(Color.Text.primary)

            metadataRow
            categoryRow
            if let transitRoute {
                transitRouteCard(transitRoute)
            } else if let location {
                locationCard(location)
            }
            memoriesSection
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.Background.elevated)
        )
    }

    // MARK: Metadata row

    private var metadataRow: some View {
        HStack(spacing: 8) {
            TicketDetailItem(label: "Created on",  sublabel: creationDate)
            TicketDetailItem(label: "Last edited", sublabel: lastEditDate)
        }
    }

    // MARK: Category tile

    private var categoryRow: some View {
        TicketDetailsCategoryTile(category: category)
    }

    // MARK: Location card

    private func locationCard(_ location: TicketLocation) -> some View {
        let key = Self.locationKey(location)
        return ZStack(alignment: .bottom) {
            Map(position: $locationCamera, interactionModes: []) {
                Marker(location.name, coordinate: location.coordinate)
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .all))
            .allowsHitTesting(false)
            .onAppear { locationCamera = Self.locationRegion(location) }
            .onChange(of: key) { _, _ in
                withAnimation(.easeInOut(duration: 0.4)) {
                    locationCamera = Self.locationRegion(location)
                }
            }

            locationNamePill(location)
                .padding(8)
        }
        .frame(height: 141)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private static func locationKey(_ l: TicketLocation) -> String {
        "\(l.lat),\(l.lng)"
    }

    private static func locationRegion(_ l: TicketLocation) -> MapCameraPosition {
        .region(MKCoordinateRegion(
            center: l.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        ))
    }

    // MARK: Transit route card

    private func transitRouteCard(_ route: TransitRoutePath) -> some View {
        let tint = Color(hex: route.lineColorHex)
        let key = Self.routeKey(route)
        return ZStack(alignment: .bottom) {
            Map(position: $routeCamera, interactionModes: []) {
                MapPolyline(coordinates: route.coordinates)
                    .stroke(tint, style: StrokeStyle(
                        lineWidth: 4,
                        lineCap: .round,
                        lineJoin: .round
                    ))
                Marker(route.origin.name, coordinate: route.origin.coordinate)
                    .tint(tint)
                Marker(route.destination.name, coordinate: route.destination.coordinate)
                    .tint(tint)
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .all))
            .allowsHitTesting(false)
            .onAppear {
                routeCamera = .region(Self.region(for: route.coordinates))
            }
            .onChange(of: key) { _, _ in
                withAnimation(.easeInOut(duration: 0.4)) {
                    routeCamera = .region(Self.region(for: route.coordinates))
                }
            }

            transitRoutePill(route, tint: tint)
                .padding(8)
        }
        .frame(height: 141)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private static func routeKey(_ r: TransitRoutePath) -> String {
        "\(r.lineShortName)|\(r.origin.lat),\(r.origin.lng)|\(r.destination.lat),\(r.destination.lng)"
    }

    private func transitRoutePill(
        _ route: TransitRoutePath,
        tint: Color
    ) -> some View {
        HStack(spacing: 8) {
            Text(route.lineShortName)
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(tint)
                )
            Text("\(route.origin.name)  →  \(route.destination.name)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.Background.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Bounding-box region with generous padding so both endpoint
    /// markers sit comfortably inside the 141-pt card — the marker
    /// bubbles and the bottom pill both occlude part of the map, so
    /// the visible region needs to be larger than the polyline's
    /// bounding box. Same delta on both axes so the smaller dimension
    /// of the card (height) doesn't crop the line.
    private static func region(
        for coords: [CLLocationCoordinate2D]
    ) -> MKCoordinateRegion {
        guard
            let firstLat = coords.first?.latitude,
            let firstLng = coords.first?.longitude
        else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
        }
        var minLat = firstLat, maxLat = firstLat
        var minLng = firstLng, maxLng = firstLng
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let latRange = maxLat - minLat
        let lngRange = maxLng - minLng
        // Scale the span to the actual endpoint gap so close-adjacent
        // stations (Tokyo Marunouchi: Shinjuku → Shinjuku-sanchome,
        // ~360 m) don't get crushed under a wide minimum zoom that
        // visually merges the two markers. Factor 2.0 keeps the pins
        // ~20-25 % of the visible horizontal width apart on the card's
        // ~2.5 aspect ratio — wide enough that the marker bubbles
        // never overlap. Floor at 0.005° (~555 m) protects against a
        // degenerate near-zero range while staying tight enough that
        // a short polyline still reads as a journey, not a city map.
        let baseRange = max(latRange, lngRange, 0.0001)
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.005, baseRange * 2.0),
            longitudeDelta: max(0.005, baseRange * 2.0)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private func locationNamePill(_ location: TicketLocation) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: "📍")
                .font(.footnote)
            Text(locationPillLabel(location))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.Background.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func locationPillLabel(_ location: TicketLocation) -> String {
        if let subtitle = location.subtitle, !subtitle.isEmpty {
            return "\(subtitle) · \(location.name)"
        }
        return location.name
    }

    // MARK: Memories section

    private var memoriesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(memoriesTitle)
                    .font(.title2.bold())
                    .foregroundStyle(Color.Text.primary)

                Spacer(minLength: 0)

                LumoriaContextualMenuButton(items: menuItems) {
                    Image(systemName: "ellipsis")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.Text.primary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle().fill(Color.Background.fieldFill)
                        )
                }
            }

            memoriesContent()
        }
    }
}

// MARK: - Preview

#Preview("No memory, with location") {
    TicketDetailsCard(
        creationDate: "03 January 2025",
        lastEditDate: "15 January 2025",
        category: .plane,
        location: TicketLocation(
            name: "Tokyo Narita",
            subtitle: "NRT",
            city: "Tokyo",
            country: "Japan",
            countryCode: "JP",
            lat: 35.7720,
            lng: 140.3929,
            kind: .airport
        ),
        menuItems: [
            .init(title: "Create memory…", action: {}),
        ],
        memoriesContent: {
            Text(verbatim: "You have no memories yet. To create a memory, tap the + icon.")
                .font(.subheadline)
                .foregroundStyle(Color.Text.secondary)
        }
    )
    .frame(width: 408)
    .padding(24)
    .background(Color.Background.default)
}

#Preview("With memory cards") {
    TicketDetailsCard(
        creationDate: "03 January 2025",
        lastEditDate: "15 January 2025",
        category: .plane,
        location: nil,
        menuItems: [
            .init(title: "Create memory…", action: {}),
            .init(title: "Add to a memory…", action: {}),
            .init(title: "Remove from memory…", kind: .destructive, action: {}),
        ],
        memoriesContent: {
            HStack(spacing: 16) {
                MemoryCard(
                    title: "Japan 2026",
                    subtitle: "2 tickets",
                    state: .normal,
                    emoji: "🗾",
                    filledCount: 2,
                    colorFamily: "Blue"
                )
                MemoryCard(
                    title: "Family",
                    subtitle: "4 tickets",
                    state: .normal,
                    emoji: "❤️",
                    filledCount: 3,
                    colorFamily: "Pink"
                )
            }
        }
    )
    .frame(width: 408)
    .padding(24)
    .background(Color.Background.default)
}
