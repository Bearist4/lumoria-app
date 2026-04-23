//
//  MemoryMapExporter.swift
//  Lumoria App
//
//  Renders a static UIImage of a memory's map — MKMapSnapshotter for the
//  base map, then Core Graphics for the dotted route polyline and a flat
//  teardrop pin per stop. Used by the "Export map…" action in
//  `MemoryMapView`.
//

import CoreLocation
import MapKit
import UIKit

enum MemoryMapExporter {

    /// Async render helper. Completion fires on the main thread with the
    /// composed image, or `nil` if snapshot generation failed.
    static func render(
        region: MKCoordinateRegion,
        pins: [(CLLocationCoordinate2D, TicketCategoryStyle)],
        polyline: [CLLocationCoordinate2D],
        size: CGSize,
        completion: @escaping (UIImage?) -> Void
    ) {
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = UIScreen.main.scale
        options.mapType = .standard
        options.pointOfInterestFilter = .includingAll

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start(with: .global(qos: .userInitiated)) { snapshot, error in
            guard let snapshot, error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let composed = compose(
                snapshot: snapshot,
                pins: pins,
                polyline: polyline,
                size: size
            )
            DispatchQueue.main.async { completion(composed) }
        }
    }

    // MARK: - Composition

    private static func compose(
        snapshot: MKMapSnapshotter.Snapshot,
        pins: [(CLLocationCoordinate2D, TicketCategoryStyle)],
        polyline: [CLLocationCoordinate2D],
        size: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            snapshot.image.draw(in: CGRect(origin: .zero, size: size))

            drawPolyline(polyline, snapshot: snapshot, in: ctx.cgContext)
            drawPins(pins, snapshot: snapshot, in: ctx.cgContext)
        }
    }

    // MARK: - Polyline

    private static func drawPolyline(
        _ coords: [CLLocationCoordinate2D],
        snapshot: MKMapSnapshotter.Snapshot,
        in ctx: CGContext
    ) {
        guard coords.count > 1 else { return }

        ctx.saveGState()
        ctx.setLineWidth(4)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineDash(phase: 0, lengths: [2, 10])
        ctx.setStrokeColor(UIColor.black.withAlphaComponent(0.75).cgColor)

        var first = true
        for coord in coords {
            let point = snapshot.point(for: coord)
            if first {
                ctx.move(to: point)
                first = false
            } else {
                ctx.addLine(to: point)
            }
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Pins

    /// Draws a simplified teardrop pin: a filled category-colored circle
    /// with a white ring, a drop-tail behind, and the SF Symbol glyph in
    /// the ring's on-color. Mirrors `TicketMapPin` for single-ticket stops.
    private static func drawPins(
        _ pins: [(CLLocationCoordinate2D, TicketCategoryStyle)],
        snapshot: MKMapSnapshotter.Snapshot,
        in ctx: CGContext
    ) {
        let pinDiameter: CGFloat = 68
        let ring: CGFloat = 6
        let tailHeight: CGFloat = 24

        for (coord, category) in pins {
            let p = snapshot.point(for: coord)

            let circleRect = CGRect(
                x: p.x - pinDiameter / 2,
                y: p.y - pinDiameter - tailHeight / 2,
                width: pinDiameter,
                height: pinDiameter
            )

            // Drop tail (white, behind the circle's ring).
            let tailPath = UIBezierPath()
            tailPath.move(to: CGPoint(x: circleRect.minX + pinDiameter * 0.35,
                                      y: circleRect.maxY - ring))
            tailPath.addLine(to: CGPoint(x: circleRect.minX + pinDiameter * 0.65,
                                          y: circleRect.maxY - ring))
            tailPath.addLine(to: CGPoint(x: p.x, y: p.y))
            tailPath.close()
            UIColor.white.setFill()
            tailPath.fill()

            // White ring.
            UIColor.white.setFill()
            UIBezierPath(ovalIn: circleRect).fill()

            // Colored disc. Resolve UIColor directly from the asset
            // catalog — avoids the SwiftUI bridging init, which some
            // build configurations miss if SwiftUI isn't fully linked.
            let discRect = circleRect.insetBy(dx: ring, dy: ring)
            let bg = UIColor(named: "Colors/\(category.colorFamily)/300") ?? .gray
            bg.setFill()
            UIBezierPath(ovalIn: discRect).fill()

            // Glyph.
            if let symbol = UIImage(systemName: category.systemImage,
                                    withConfiguration: UIImage.SymbolConfiguration(
                                        pointSize: pinDiameter * 0.4, weight: .semibold)) {
                let onColor: UIColor = category == .train ? .black : .white
                let tinted = symbol.withTintColor(onColor,
                                                  renderingMode: .alwaysOriginal)
                let glyphSize = tinted.size
                let glyphRect = CGRect(
                    x: discRect.midX - glyphSize.width / 2,
                    y: discRect.midY - glyphSize.height / 2,
                    width: glyphSize.width,
                    height: glyphSize.height
                )
                tinted.draw(in: glyphRect)
            }
        }
    }
}
