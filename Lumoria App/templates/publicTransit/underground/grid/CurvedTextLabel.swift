//
//  CurvedTextLabel.swift
//  Lumoria App
//
//  Single-line text laid out along a circular arc — used by the
//  Grid public-transport template to wrap the line name above the
//  bullet ("Circle line ↗"), the city below it ("↘ London"), and
//  the from→destination arc near the bottom of the ticket.
//
//  SwiftUI doesn't ship a text-on-path primitive, so each character
//  is positioned individually around a center on a circle of radius
//  `radius`, then rotated so it stands tangent to the arc. Two
//  directions are supported:
//   • `.outward` — character tops point AWAY from the centre, used
//     for top arcs (smile shape, "Circle line" above the bullet).
//   • `.inward`  — character tops point TOWARD the centre, used for
//     bottom arcs (frown shape, "London" below the bullet) so the
//     text reads upright.
//
//  Arcs are parameterised by a `baseAngle` (centre of the arc, 0°
//  = 12 o'clock, clockwise) and a `arcAngle` (total span). Even
//  spacing is computed from character count — no glyph-width
//  measurement, which means tracking varies a touch with letter
//  shape but reads cleanly at the small ticket sizes.
//

import SwiftUI

struct CurvedTextLabel: View {
    let text: String
    /// Radius of the circle the text is wrapped around. The label's
    /// bounding frame is `radius * 2 × radius * 2` so the parent can
    /// position it as a single unit.
    let radius: CGFloat
    /// Angle of the arc's centre, measured clockwise from 12 o'clock.
    /// `0°` = top of the circle, `180°` = bottom.
    let baseAngle: Angle
    /// Total angular span of the arc. 60-90° gives a gentle curve
    /// for short labels (≤ 12 chars).
    let arcAngle: Angle
    /// Where each character's "up" points relative to the centre.
    let direction: Direction
    var font: Font = .system(size: 13, weight: .medium)
    var tracking: CGFloat = 0
    var foregroundStyle: Color = .black

    enum Direction {
        /// Char tops point AWAY from the circle centre — top arcs.
        case outward
        /// Char tops point TOWARD the circle centre — bottom arcs.
        case inward
    }

    var body: some View {
        let characters = Array(text)
        let n = characters.count

        // Each glyph is anchored at the TOP-CENTRE of a `2*radius`
        // square (`(radius, 0)`) and the whole view rotates around
        // its centre — this sweeps the glyph onto a circle of
        // `radius`. Same technique as the `CircularText` library
        // (github.com/tyagishi/CircularText) but with an `inward`
        // mode that pre-flips each glyph 180° so it reads upright
        // when the column rotates ~180° to sit on the bottom of
        // the circle.
        //
        // `tracking` is interpreted as ADDITIONAL arc-length (in
        // points) between adjacent glyphs and converted to an
        // angular adjustment. A negative value tightens the
        // spacing; a positive value loosens it. SwiftUI's built-in
        // `.tracking()` does nothing here because each glyph is
        // its own `Text`, so spacing has to be controlled by the
        // angular layout itself.
        let trackingRad = Double(tracking / radius)
        let effectiveArc = arcAngle.radians + Double(max(n - 1, 0)) * trackingRad

        ZStack {
            ForEach(Array(characters.enumerated()), id: \.offset) { idx, char in
                let frac = n > 1 ? Double(idx) / Double(n - 1) : 0.5
                // Outward arcs sweep clockwise around `baseAngle`;
                // inward arcs sweep counter-clockwise so a bottom
                // arc reads left-to-right (otherwise "London" lands
                // as "nodnoL").
                let offset = (frac - 0.5) * effectiveArc
                let columnAngle = direction == .outward
                    ? baseAngle.radians + offset
                    : baseAngle.radians - offset

                Text(String(char))
                    .font(font)
                    .foregroundStyle(foregroundStyle)
                    .rotationEffect(direction == .inward ? .degrees(180) : .zero)
                    .position(x: radius, y: 0)
                    .rotationEffect(.radians(columnAngle))
            }
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}

#Preview("Curved arcs") {
    ZStack {
        Color.yellow.opacity(0.15)
        CurvedTextLabel(
            text: "Circle line",
            radius: 50,
            baseAngle: .degrees(0),
            arcAngle: .degrees(120),
            direction: .outward,
            font: .system(size: 14, weight: .medium),
            tracking: 1
        )
        CurvedTextLabel(
            text: "London",
            radius: 50,
            baseAngle: .degrees(180),
            arcAngle: .degrees(60),
            direction: .inward,
            font: .system(size: 14, weight: .medium),
            tracking: 1
        )
    }
    .frame(width: 200, height: 200)
}
