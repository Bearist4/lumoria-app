//
//  TicketCardShape.swift
//  Lumoria (widget)
//
//  Ticket-shaped rounded rectangle used by the widget backgrounds. Can
//  carve semicircle perforations along the left or right edge so two
//  cards sat side-by-side visually interlock the way a real torn ticket
//  stub does.
//

import SwiftUI

struct TicketCardShape: Shape {

    enum PerforatedEdge: Equatable {
        case none
        case left
        case right
    }

    var cornerRadius: CGFloat = 24
    var perforatedEdge: PerforatedEdge = .none
    /// Radius of each semicircle cutout.
    var notchRadius: CGFloat = 4
    /// Vertical distance between consecutive notch centres.
    var notchSpacing: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let cr = min(cornerRadius, min(rect.width, rect.height) / 2)
        var path = Path()

        // Start just after the top-left corner.
        path.move(to: CGPoint(x: rect.minX + cr, y: rect.minY))

        // Top edge.
        path.addLine(to: CGPoint(x: rect.maxX - cr, y: rect.minY))

        // Top-right corner (90° clockwise arc).
        path.addArc(
            center: CGPoint(x: rect.maxX - cr, y: rect.minY + cr),
            radius: cr,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )

        // Right edge — plain or notched.
        if perforatedEdge == .right {
            addNotches(
                to: &path,
                edge: .right,
                rect: rect,
                cornerInset: cr
            )
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cr))
        }

        // Bottom-right corner.
        path.addArc(
            center: CGPoint(x: rect.maxX - cr, y: rect.maxY - cr),
            radius: cr,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        // Bottom edge.
        path.addLine(to: CGPoint(x: rect.minX + cr, y: rect.maxY))

        // Bottom-left corner.
        path.addArc(
            center: CGPoint(x: rect.minX + cr, y: rect.maxY - cr),
            radius: cr,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        // Left edge — plain or notched.
        if perforatedEdge == .left {
            addNotches(
                to: &path,
                edge: .left,
                rect: rect,
                cornerInset: cr
            )
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cr))
        }

        // Top-left corner.
        path.addArc(
            center: CGPoint(x: rect.minX + cr, y: rect.minY + cr),
            radius: cr,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }

    // MARK: - Notches

    private enum Side { case left, right }

    private func addNotches(
        to path: inout Path,
        edge: Side,
        rect: CGRect,
        cornerInset: CGFloat
    ) {
        let topY    = rect.minY + cornerInset
        let bottomY = rect.maxY - cornerInset
        let usable  = bottomY - topY
        guard usable > 0 else {
            let x = edge == .right ? rect.maxX : rect.minX
            path.addLine(to: CGPoint(x: x, y: edge == .right ? bottomY : topY))
            return
        }

        let count = max(1, Int(usable / notchSpacing))
        let step  = usable / CGFloat(count + 1)

        switch edge {
        case .right:
            let x = rect.maxX
            for i in 1...count {
                let cy = topY + CGFloat(i) * step
                path.addLine(to: CGPoint(x: x, y: cy - notchRadius))
                // Semicircle bulging left (into the card) — from angle
                // -90° through 180° to 90°, counter-clockwise in screen
                // coordinates.
                path.addArc(
                    center: CGPoint(x: x, y: cy),
                    radius: notchRadius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(90),
                    clockwise: true
                )
            }
            path.addLine(to: CGPoint(x: x, y: bottomY))

        case .left:
            let x = rect.minX
            // Traversing upward along the left edge, so iterate from
            // bottom to top.
            for i in 1...count {
                let cy = bottomY - CGFloat(i) * step
                path.addLine(to: CGPoint(x: x, y: cy + notchRadius))
                // Semicircle bulging right (into the card).
                path.addArc(
                    center: CGPoint(x: x, y: cy),
                    radius: notchRadius,
                    startAngle: .degrees(90),
                    endAngle: .degrees(-90),
                    clockwise: true
                )
            }
            path.addLine(to: CGPoint(x: x, y: topY))
        }
    }
}
