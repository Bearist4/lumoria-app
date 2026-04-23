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
//
//  Bottom sheet `MemoryDataArea` surfaces four journey stats (tickets,
//  days, categories, kilometers). A top-right overflow menu opens a
//  Timeline overlay and an Export action that snapshots the current map
//  region + pins + polyline and hands the result to the system share
//  sheet.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1652-47256
//

import CoreLocation
import MapKit
import SwiftUI

struct MemoryMapView: View {
    @Environment(\.dismiss) private var dismiss

    let memory: Memory
    let tickets: [Ticket]
    /// User-defined stops. Empty list is fine — anchors are optional.
    let anchors: [JourneyAnchor]

    @AppStorage("map.style")        private var mapStyleRaw:  String = MapStylePref.standard.rawValue
    @AppStorage("map.showPOIs")     private var showPOIs:     Bool   = true
    @AppStorage("map.reduceMotion") private var reduceMotion: Bool   = false

    @State private var camera: MapCameraPosition
    @State private var selectedTicket: Ticket?
    @State private var selectedGroup: GroupedPin?
    /// Toggled from the overflow menu — switches the bottom card
    /// between the stat grid and the chronological film strip.
    @State private var showTimeline: Bool = false
    /// Stop / anchor under the timeline playhead. Only meaningful when
    /// `showTimeline` is true.
    @State private var selectedStopId: UUID? = nil
    @State private var shareImage: IdentifiableImage?
    @State private var exportInFlight = false

    init(
        memory: Memory,
        tickets: [Ticket],
        anchors: [JourneyAnchor] = []
    ) {
        self.memory = memory
        self.tickets = tickets
        self.anchors = anchors
        _camera = State(initialValue: Self.initialCamera(for: tickets, anchors: anchors))
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            mapLayer
                .ignoresSafeArea()

            if showTimeline {
                MemoryTimeline(
                    stops: timelineStops,
                    startDate: memory.startDate,
                    endDate: memory.endDate,
                    selectedStopId: $selectedStopId
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                MemoryDataArea(
                    memory: memory,
                    tickets: tickets,
                    anchors: anchors
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showTimeline)
        .onChange(of: selectedStopId) { oldId, newId in
            handleStopSelection(oldId: oldId, newId: newId)
        }
        .onChange(of: showTimeline) { _, isOn in
            if isOn {
                // Land on the start anchor so the map opens on a
                // fit-all overview, with the start icon highlighted.
                selectedStopId = MemoryTimeline.startAnchorId
            } else {
                withAnimation(.easeInOut(duration: 0.6)) {
                    camera = Self.initialCamera(for: tickets, anchors: anchors)
                }
                selectedStopId = nil
            }
        }
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
        .overlay(alignment: .topTrailing) {
            LumoriaIconButton(
                systemImage: "ellipsis",
                size: .large,
                position: .onSurface,
                menuItems: menuItems
            )
            .padding(.trailing, 16)
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        selectedTicket = ticket
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $shareImage) { wrapper in
            ShareSheet(items: [wrapper.image])
        }
    }

    // MARK: - Map layer

    private var mapLayer: some View {
        Map(position: $camera) {
            // Dotted curved polyline connecting all stops in chronological
            // order. Drawn BEFORE pins so pins overlay the line.
            if storyCoordinates.count > 1 {
                MapPolyline(coordinates: MemoryJourneyPath.curved(storyCoordinates))
                    .stroke(
                        Color.black.opacity(0.75),
                        style: StrokeStyle(
                            lineWidth: 3,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [2, 8]
                        )
                    )
            }

            if showTimeline {
                // Timeline mode — one pin per stop, the selected one
                // scales up so the user can see which tile the
                // playhead is hovering.
                ForEach(timelineStops) { stop in
                    Annotation("", coordinate: coordinate(for: stop), anchor: .bottom) {
                        stopPinView(for: stop)
                    }
                }
            } else {
                // Default mode — clustered pins that route to detail.
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
        }
        .mapStyle(resolvedMapStyle)
    }

    /// Map style resolved from the user's preferences.
    private var resolvedMapStyle: MapStyle {
        let pref = MapStylePref(rawValue: mapStyleRaw) ?? .standard
        let poiFilter: PointOfInterestCategories = showPOIs ? .all : .excludingAll
        switch pref {
        case .standard:
            return .standard(elevation: .realistic, pointsOfInterest: poiFilter)
        case .hybrid:
            return .hybrid(elevation: .realistic, pointsOfInterest: poiFilter)
        }
    }

    // MARK: - Menu

    private var menuItems: [LumoriaMenuItem] {
        [
            .init(
                title: showTimeline ? "Hide timeline" : "View timeline"
            ) {
                showTimeline.toggle()
            },
        ]
    }

    // MARK: - Timeline mode

    /// Chronological list of stops used when the timeline is visible.
    /// Each ticket contributes up to two stops (origin + destination);
    /// anchors slot in by date. IDs are stable per (ticket, role) so
    /// selection survives re-renders.
    private var timelineStops: [TimelineStop] {
        var out: [TimelineStop] = []
        for t in tickets {
            if t.originLocation != nil {
                out.append(.ticket(
                    id: syntheticId(for: t, role: .origin),
                    ticket: t,
                    role: .origin,
                    date: t.createdAt
                ))
            }
            if t.destinationLocation != nil {
                out.append(.ticket(
                    id: syntheticId(for: t, role: .destination),
                    ticket: t,
                    role: .destination,
                    date: t.createdAt
                ))
            }
        }
        for a in anchors {
            out.append(.anchor(a))
        }
        out.sort { $0.date < $1.date }
        return out
    }

    private func syntheticId(for ticket: Ticket, role: TimelineTicketRole) -> UUID {
        var bytes = withUnsafeBytes(of: ticket.id.uuid) { Array($0) }
        bytes[15] = role == .origin ? 0xA0 : 0xB0
        let uuid = (bytes[0], bytes[1], bytes[2], bytes[3],
                    bytes[4], bytes[5], bytes[6], bytes[7],
                    bytes[8], bytes[9], bytes[10], bytes[11],
                    bytes[12], bytes[13], bytes[14], bytes[15])
        return UUID(uuid: uuid)
    }

    private func coordinate(for stop: TimelineStop) -> CLLocationCoordinate2D {
        switch stop {
        case .ticket(_, let t, let role, _):
            switch role {
            case .origin:
                if let o = t.originLocation?.coordinate { return o }
            case .destination:
                if let d = t.destinationLocation?.coordinate { return d }
            }
            return t.originLocation?.coordinate
                ?? t.destinationLocation?.coordinate
                ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        case .anchor(let a):
            return a.coordinate
        }
    }

    @ViewBuilder
    private func stopPinView(for stop: TimelineStop) -> some View {
        let isSelected = selectedStopId == stop.id
        let scale: CGFloat = isSelected ? 1.18 : 1
        let anim: Animation = reduceMotion
            ? .easeInOut(duration: 0.18)
            : .spring(response: 0.45, dampingFraction: 0.75)
        switch stop {
        case .ticket(_, let ticket, _, _):
            TicketMapPin(category: ticket.kind.categoryStyle)
                .scaleEffect(scale)
                .animation(anim, value: isSelected)
        case .anchor(let a):
            ZStack {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                Image(systemName: anchorSymbol(a.kind))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(scale)
            .animation(anim, value: isSelected)
        }
    }

    private func anchorSymbol(_ kind: JourneyAnchorKind) -> String {
        switch kind {
        case .start:    return "house.fill"
        case .end:      return "flag.fill"
        case .waypoint: return "mappin"
        }
    }

    // MARK: - Camera (timeline mode)

    private static let restingDistance: CLLocationDistance = 8_000
    private static let cameraPitch: CGFloat = 55

    private static func tilted(
        center: CLLocationCoordinate2D,
        distance: CLLocationDistance
    ) -> MapCameraPosition {
        .camera(MapCamera(
            centerCoordinate: center,
            distance: distance,
            heading: 0,
            pitch: cameraPitch
        ))
    }

    /// Routes a `selectedStopId` change to the right camera animation.
    /// Start/end timeline anchors fit every pin; a stop id zooms in on
    /// that stop with a smooth dezoom-through-midpoint transition.
    private func handleStopSelection(oldId: UUID?, newId: UUID?) {
        guard showTimeline, let newId else { return }

        // Reduce-motion users get a single straight ease instead of the
        // dezoom-through-midpoint chain.
        let fitDuration: Double = reduceMotion ? 0.25 : 0.6
        let pullOutDuration: Double = reduceMotion ? 0.25 : 0.45
        let settleDuration: Double = reduceMotion ? 0.25 : 0.55

        if newId == MemoryTimeline.startAnchorId ||
           newId == MemoryTimeline.endAnchorId {
            withAnimation(.easeInOut(duration: fitDuration)) {
                camera = Self.initialCamera(for: tickets, anchors: anchors)
            }
            return
        }

        guard let newStop = timelineStops.first(where: { $0.id == newId })
        else { return }

        let newCoord = coordinate(for: newStop)

        guard
            let oldId,
            let oldStop = timelineStops.first(where: { $0.id == oldId }),
            !reduceMotion
        else {
            withAnimation(.easeInOut(duration: fitDuration)) {
                camera = Self.tilted(center: newCoord, distance: Self.restingDistance)
            }
            return
        }

        let oldCoord = coordinate(for: oldStop)
        let midCoord = CLLocationCoordinate2D(
            latitude:  (oldCoord.latitude  + newCoord.latitude)  / 2,
            longitude: (oldCoord.longitude + newCoord.longitude) / 2
        )
        let legMeters = haversineMeters(oldCoord, newCoord)
        let pullOutDistance = max(Self.restingDistance, legMeters * 2.4 + 3_000)

        withAnimation(.easeInOut(duration: pullOutDuration)) {
            camera = Self.tilted(center: midCoord, distance: pullOutDistance)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + pullOutDuration + 0.03) {
            withAnimation(.easeInOut(duration: settleDuration)) {
                camera = Self.tilted(center: newCoord, distance: Self.restingDistance)
            }
        }
    }

    private func haversineMeters(
        _ a: CLLocationCoordinate2D,
        _ b: CLLocationCoordinate2D
    ) -> Double {
        let r = 6_371_000.0
        let dLat = (b.latitude  - a.latitude)  * .pi / 180
        let dLng = (b.longitude - a.longitude) * .pi / 180
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
              + sin(dLng / 2) * sin(dLng / 2) * cos(lat1) * cos(lat2)
        return 2 * r * asin(min(1, sqrt(h)))
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

        var headerName: String { items.first?.location.name ?? "" }

        static func == (lhs: GroupedPin, rhs: GroupedPin) -> Bool {
            lhs.id == rhs.id
        }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    /// One annotation per ticket-location pairing.
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

    /// Groups `annotations` by rounded coordinate (~1m precision).
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

    /// Coordinates in the order they should appear on the dotted polyline.
    /// Tickets contribute origin→destination pairs in chronological order;
    /// anchors slot in by `date`. Consecutive duplicates are dropped so the
    /// line doesn't fold back on itself at cluster pins.
    private var storyCoordinates: [CLLocationCoordinate2D] {
        var stops: [(date: Date, coord: CLLocationCoordinate2D)] = []

        for t in tickets {
            if let o = t.originLocation?.coordinate {
                stops.append((t.createdAt, o))
            }
            if let d = t.destinationLocation?.coordinate {
                stops.append((t.createdAt, d))
            }
        }
        for a in anchors {
            stops.append((a.date, a.coordinate))
        }

        stops.sort { $0.date < $1.date }

        var out: [CLLocationCoordinate2D] = []
        for s in stops {
            if let last = out.last,
               Self.coordinateKey(last) == Self.coordinateKey(s.coord) {
                continue
            }
            out.append(s.coord)
        }
        return out
    }

    private static func coordinateKey(_ c: CLLocationCoordinate2D) -> String {
        String(format: "%.5f_%.5f", c.latitude, c.longitude)
    }

    // MARK: - Camera

    /// Computes an initial camera position that frames every pin and
    /// every anchor.
    ///
    /// A standard-style Mercator map on a portrait phone can't
    /// physically show more than ~80° of longitude at once (beyond
    /// that MapKit clamps vertical extent to the earth's height and
    /// the horizontal stops growing). So for routes wider than that
    /// we drop to `MKMapRect.world` — the pan-the-globe view — which
    /// always frames every pin at the cost of a more zoomed-out feel.
    /// Smaller routes use a computed region with generous padding.
    private static func initialCamera(
        for tickets: [Ticket],
        anchors: [JourneyAnchor]
    ) -> MapCameraPosition {
        var coords: [CLLocationCoordinate2D] = tickets.flatMap { t in
            [t.originLocation?.coordinate, t.destinationLocation?.coordinate]
                .compactMap { $0 }
        }
        coords.append(contentsOf: anchors.map(\.coordinate))

        guard let first = coords.first else {
            return .rect(MKMapRect.world)
        }
        guard coords.count > 1 else {
            return .region(MKCoordinateRegion(
                center: first,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }

        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let latSpan = lats.max()! - lats.min()!
        let lngSpan = lngs.max()! - lngs.min()!

        // Beyond this lng span the portrait aspect forces MapKit to
        // clamp vertically and pins start dropping off the sides.
        let portraitMaxLng: Double = 80

        if lngSpan > portraitMaxLng || latSpan > 70 {
            // Force MapKit's minimum zoom level (fully zoomed out)
            // centered on the pins' centroid. `distance` is in meters
            // from camera to ground; pushing it well past earth's
            // diameter (~12.7M m) lets MapKit clamp to the widest
            // zoom it supports — effectively "zoom level 0".
            let center = CLLocationCoordinate2D(
                latitude: (lats.min()! + lats.max()!) / 2,
                longitude: (lngs.min()! + lngs.max()!) / 2
            )
            return .camera(MapCamera(
                centerCoordinate: center,
                distance: 1_000_000_000,
                heading: 0,
                pitch: 0
            ))
        }

        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  max(0.05, latSpan * paddingFactor(for: latSpan)),
            longitudeDelta: max(0.05, lngSpan * paddingFactor(for: lngSpan))
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    private static func paddingFactor(for rawDegrees: Double) -> Double {
        switch rawDegrees {
        case ..<1:   return 1.8
        case ..<10:  return 1.5
        case ..<40:  return 1.3
        default:     return 1.15
        }
    }

    // MARK: - Export

    /// Renders an MKMapSnapshotter image of the current region with pins
    /// overlaid, then hands it to the system share sheet. Runs off-main
    /// until the UIImage is ready.
    private func exportMap() {
        guard !exportInFlight else { return }
        exportInFlight = true

        let coords = storyCoordinates
        let region = Self.regionFitting(
            coords: coords.isEmpty ? (annotations.map(\.coordinate)) : coords
        )
        let size = CGSize(width: 1080, height: 1920)

        MemoryMapExporter.render(
            region: region,
            pins: annotations.map { ($0.coordinate, $0.ticket.kind.categoryStyle) },
            polyline: MemoryJourneyPath.curved(coords),
            size: size
        ) { image in
            exportInFlight = false
            guard let image else { return }
            shareImage = IdentifiableImage(image: image)
        }
    }

    private static func regionFitting(
        coords: [CLLocationCoordinate2D]
    ) -> MKCoordinateRegion {
        guard let first = coords.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
            )
        }
        guard coords.count > 1 else {
            return MKCoordinateRegion(
                center: first,
                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
            )
        }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (lats.min()! + lats.max()!) / 2,
                longitude: (lngs.min()! + lngs.max()!) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta:  max(0.3, (lats.max()! - lats.min()!) * 1.8),
                longitudeDelta: max(0.3, (lngs.max()! - lngs.min()!) * 1.8)
            )
        )
    }
}

// MARK: - Share sheet wrapper

private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Pin bottom sheet

/// Sheet listing the tickets that share a single map pin.
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
        startDate: nil, endDate: nil,
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

// MARK: - Tokyo 4-day multi-category preview

private let previewTokyoStation = TicketLocation(
    name: "Tokyo Station", subtitle: "TYO",
    city: "Tokyo", country: "Japan", countryCode: "JP",
    lat: 35.6812, lng: 139.7671, kind: .station
)

private let previewShibuya = TicketLocation(
    name: "Shibuya Station", subtitle: "SBY",
    city: "Tokyo", country: "Japan", countryCode: "JP",
    lat: 35.6580, lng: 139.7016, kind: .station
)

private let previewShinjuku = TicketLocation(
    name: "Shinjuku Station", subtitle: "SJK",
    city: "Tokyo", country: "Japan", countryCode: "JP",
    lat: 35.6896, lng: 139.7006, kind: .station
)

private let previewAsakusa = TicketLocation(
    name: "Asakusa Station", subtitle: "ASK",
    city: "Tokyo", country: "Japan", countryCode: "JP",
    lat: 35.7148, lng: 139.7967, kind: .station
)

private let previewBudokan = TicketLocation(
    name: "Nippon Budokan", subtitle: "武道館",
    city: "Tokyo", country: "Japan", countryCode: "JP",
    lat: 35.6933, lng: 139.7499, kind: .venue
)

/// Shinkansen-style ticket between two Tokyo stations on `date`.
private func tokyoTrainTicket(
    origin: TicketLocation,
    destination: TicketLocation,
    date: Date,
    memoryId: UUID
) -> Ticket {
    Ticket(
        id: UUID(),
        createdAt: date,
        updatedAt: date,
        orientation: .horizontal,
        payload: .express(ExpressTicket(
            trainType: "Shinkansen",
            trainNumber: "Hikari 503",
            cabinClass: "Green",
            originCity: origin.name,
            originCityKanji: "東京",
            destinationCity: destination.name,
            destinationCityKanji: "",
            date: "24.06.2026",
            departureTime: "09:15",
            arrivalTime: "09:42",
            car: "7",
            seat: "14A",
            ticketNumber: "TKY-000001"
        )),
        memoryIds: [memoryId],
        originLocation: origin,
        destinationLocation: destination
    )
}

/// Plane ticket between the two Tokyo airports on `date`.
private func tokyoPlaneTicket(
    origin: TicketLocation,
    destination: TicketLocation,
    date: Date,
    memoryId: UUID
) -> Ticket {
    let base = TicketsStore.sampleTickets[0]
    return Ticket(
        id: UUID(),
        createdAt: date,
        updatedAt: date,
        orientation: base.orientation,
        payload: base.payload,
        memoryIds: [memoryId],
        originLocation: origin,
        destinationLocation: destination
    )
}

/// Concert ticket anchored at a venue.
private func tokyoConcertTicket(
    at venue: TicketLocation,
    date: Date,
    memoryId: UUID
) -> Ticket {
    Ticket(
        id: UUID(),
        createdAt: date,
        updatedAt: date,
        orientation: .vertical,
        payload: .concert(ConcertTicket(
            artist: "Madison Beer",
            tourName: "The Locket Tour",
            venue: venue.name,
            date: "25 Jun 2026",
            doorsTime: "19:00",
            showTime: "20:30",
            ticketNumber: "CON-2026-000142"
        )),
        memoryIds: [memoryId],
        originLocation: venue
    )
}

#Preview("Tokyo · 4 days · multi-category") {
    let cal = Calendar.current
    let day1 = cal.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 10))!
    let day2 = cal.date(from: DateComponents(year: 2026, month: 6, day: 24, hour: 11))!
    let day3 = cal.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 20))!
    let day4 = cal.date(from: DateComponents(year: 2026, month: 6, day: 26, hour: 9))!

    let memory = Memory(
        id: UUID(), userId: UUID(),
        name: "Tokyo 2026",
        colorFamily: "Pink",
        emoji: "🗼",
        startDate: day1,
        endDate:   day4,
        createdAt: .now, updatedAt: .now
    )

    return MemoryMapView(
        memory: memory,
        tickets: [
            // Day 1 — arrive HND, relocation hop to NRT
            tokyoPlaneTicket(
                origin: previewHaneda,
                destination: previewNarita,
                date: day1,
                memoryId: memory.id
            ),
            // Day 2 — train Tokyo → Shibuya
            tokyoTrainTicket(
                origin: previewTokyoStation,
                destination: previewShibuya,
                date: day2,
                memoryId: memory.id
            ),
            // Day 3 — concert at Budokan
            tokyoConcertTicket(
                at: previewBudokan,
                date: day3,
                memoryId: memory.id
            ),
            // Day 4 — train Shinjuku → Asakusa
            tokyoTrainTicket(
                origin: previewShinjuku,
                destination: previewAsakusa,
                date: day4,
                memoryId: memory.id
            ),
        ]
    )
    .environmentObject(TicketsStore())
    .environmentObject(MemoriesStore())
}

