//
//  CollectionsMapView.swift
//  Lumoria App
//
//  Full-screen map that plots each collection with a stored location.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-12559
//

import SwiftUI
import MapKit
import CoreLocation

struct CollectionsMapView: View {
    @Environment(\.dismiss) private var dismiss

    let collections: [Collection]

    @State private var camera: MapCameraPosition

    init(collections: [Collection]) {
        self.collections = collections
        _camera = State(initialValue: Self.initialCamera(for: collections))
    }

    var body: some View {
        Map(position: $camera) {
            ForEach(located) { c in
                if let coord = c.coordinate {
                    Annotation(c.name, coordinate: coord, anchor: .bottom) {
                        CollectionMapPin(
                            color: Color("Colors/\(c.colorFamily)/500"),
                            label: c.name
                        )
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .all))
        .ignoresSafeArea()
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
    }

    // MARK: Helpers

    private var located: [Collection] {
        collections.filter { $0.coordinate != nil }
    }

    /// Fits the initial camera region to the collection of pins.
    private static func initialCamera(for collections: [Collection]) -> MapCameraPosition {
        let coords = collections.compactMap { $0.coordinate }
        guard let first = coords.first else {
            return .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
                span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
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
        let span = MKCoordinateSpan(
            latitudeDelta:  max(0.05, (lats.max()! - lats.min()!) * 1.4),
            longitudeDelta: max(0.05, (lngs.max()! - lngs.min()!) * 1.4)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }
}

// MARK: - Pin

struct CollectionMapPin: View {
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle().stroke(.white, lineWidth: 4)
                    )

                Image(systemName: "figure.walk")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Triangle()
                .fill(.white)
                .frame(width: 10, height: 6)
                .offset(y: -6)

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(-0.27)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color(hex: "2B2B2B"))
                )
                .overlay(
                    Capsule().stroke(.white.opacity(0.5), lineWidth: 0.6)
                )
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Collection helpers

extension Collection {
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = locationLat, let lng = locationLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var hasLocation: Bool { coordinate != nil }
}
