//
//  HeritageTicketVerticalView.swift
//  Lumoria App
//
//  Vertical boarding-pass card for the "Heritage" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=1-2063
//
//  Self-contained: every shape (envelope, plane, perforations) and
//  the bg-composition view live in this file so the horizontal
//  Heritage view stays untouched. Coordinates use 260×455 vertical
//  space; paths are written natively (no `.rotationEffect` at the
//  view layer) so SwiftUI's layout system never sees a rotated
//  size mismatch.
//

import SwiftUI

struct HeritageTicketVerticalView: View {
    let ticket: HeritageTicket
    var style: TicketStyleVariant = TicketTemplateKind.heritage.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    /// 4-step ramp derived from `style.accent`. Mirrors the horizontal
    /// view's behaviour — single user pick recolours every blue tone.
    private var ramp: HeritageRamp { HeritageRamp(base: style.accent) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack(alignment: .topLeading) {
                HeritageVerticalBackground(
                    surfaceFill: style.backgroundColor ?? .white,
                    planeFill: ramp.shade100,
                    width: w,
                    height: h
                )
                .styleAnchor(.accent)

                // Background anchor — perforation row sits at y≈381,
                // x=22..234 (90° CCW transform places the rotated
                // horizontal column near the bottom of the ticket).
                Color.clear
                    .frame(width: (240 - 22) * s, height: 4 * s)
                    .offset(x: 22 * s, y: 379 * s)
                    .styleAnchor(.background)

                headerRow(scale: s)
                    .frame(width: w)
                    .offset(x: 0, y: 0)

                routeStack(scale: s)
                    .frame(width: w)
                    .offset(x: 0, y: 75 * s)

                detailsRow(scale: s)
                    .frame(width: w)
                    .offset(x: 0, y: 319 * s)

                footerRow(scale: s)
                    .frame(width: w)
                    .offset(x: 0, y: 381 * s)
            }
            .frame(width: w, height: h)
            // Outer clip — same envelope shape used by the bg layer.
            // Eo-fill so the perforation circles + tab notches stay
            // transparent through every stacked element.
            .clipShape(HeritageVerticalEnvelope(),
                       style: FillStyle(eoFill: true))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Header

    private func headerRow(scale s: CGFloat) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4 * s) {
                Text(ticket.airline.uppercased())
                    .font(.system(size: 8 * s, weight: .bold))
                    .tracking(1.5 * s)
                    .foregroundStyle(ramp.shade400)

                Text(ticket.ticketNumber)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(0.5 * s)
                    .foregroundStyle(ramp.shade700)
            }

            Spacer(minLength: 0)

            Text(ticket.cabinClass.uppercased())
                .font(.system(size: 6 * s, weight: .bold))
                .tracking(0.64 * s)
                .foregroundStyle(style.onAccent)
                .styleAnchor(.onAccent)
                .padding(.horizontal, 8 * s)
                .padding(.vertical, 4 * s)
                .background(
                    RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
                        .fill(ramp.shade400)
                )
        }
        .padding(16 * s)
    }

    // MARK: - Route stack

    private func routeStack(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8 * s) {
            airportBlock(
                code: ticket.origin,
                name: ticket.originName,
                location: ticket.originLocation,
                codeColor: ramp.shade500,
                anchor: false,
                scale: s
            )

            HStack(spacing: 8 * s) {
                Text(verbatim: "↓")
                    .font(.custom("Georgia", size: 12.235 * s))
                    .foregroundStyle(style.textPrimary)

                Text(ticket.flightDuration.uppercased())
                    .font(.system(size: 5.35 * s, weight: .bold))
                    .tracking(1.18 * s)
                    .foregroundStyle(style.textPrimary)
            }

            airportBlock(
                code: ticket.destination,
                name: ticket.destinationName,
                location: ticket.destinationLocation,
                codeColor: ramp.shade700,
                anchor: true,
                scale: s
            )
        }
        .padding(.horizontal, 16 * s)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func airportBlock(
        code: String,
        name: String,
        location: String,
        codeColor: Color,
        anchor: Bool,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4 * s) {
            Text(code)
                .font(.custom("Georgia-Bold", size: 64 * s))
                .foregroundStyle(codeColor)
                .blendMode(.multiply)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            // Anchor only the destination block — single .textPrimary
            // anchor is enough for the preview pill.
            Group {
                if anchor {
                    Text(name).styleAnchor(.textPrimary)
                } else {
                    Text(name)
                }
            }
            .font(.system(size: 8 * s, weight: .bold))
            .foregroundStyle(style.textPrimary)
            .lineLimit(1)

            Text(location.uppercased())
                .font(.system(size: 6 * s, weight: .regular))
                .tracking(0.5 * s)
                .foregroundStyle(style.textPrimary.opacity(0.4))
                .lineLimit(1)
        }
    }

    // MARK: - Details 5-cell row

    private func detailsRow(scale s: CGFloat) -> some View {
        HStack(spacing: 0) {
            detailCell(label: "Gate",    value: ticket.gate,          showDivider: false, scale: s)
            detailCell(label: "Seat",    value: ticket.seat,          showDivider: true,  scale: s)
            detailCell(label: "Boards",  value: ticket.boardingTime,  showDivider: true,  scale: s)
            detailCell(label: "Departs", value: ticket.departureTime, showDivider: true,  scale: s)
            detailCell(label: "Date",    value: ticket.date,          showDivider: true,  scale: s)
        }
        .padding(16 * s)
    }

    private func detailCell(
        label: String,
        value: String,
        showDivider: Bool,
        scale s: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            if showDivider {
                Rectangle()
                    .fill(style.textPrimary.opacity(0.1))
                    .frame(width: 0.5)
            }

            VStack(spacing: 4 * s) {
                Text(label).textCase(.uppercase)
                    .font(.system(size: 4.59 * s, weight: .medium))
                    .tracking(1.0 * s)
                    .foregroundStyle(ramp.shade500)

                Text(value)
                    .font(.system(size: 9.18 * s, weight: .bold))
                    .foregroundStyle(style.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 29.82 * s)
    }

    // MARK: - Footer

    private func footerRow(scale s: CGFloat) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4 * s) {
                Text("\(ticket.origin) → \(ticket.destination)")
                    .font(.system(size: 8 * s, weight: .bold))
                    .foregroundStyle(style.textPrimary.opacity(0.6))

                Text(ticket.fullDate)
                    .font(.system(size: 10 * s, weight: .bold))
                    .foregroundStyle(style.textPrimary.opacity(0.4))

                Text(ticket.cabinDetail.uppercased())
                    .font(.system(size: 6 * s, weight: .bold))
                    .tracking(2 * s)
                    .foregroundStyle(style.textPrimary.opacity(0.4))
            }

            Spacer(minLength: 0)

            madeWithBadge(scale: s)
        }
        .padding(.horizontal, 16 * s)
        .padding(.vertical, 12 * s)
    }

    @ViewBuilder
    private func madeWithBadge(scale s: CGFloat) -> some View {
        if showsLumoriaWatermark {
            MadeWithLumoria(style: .black, version: .small, scale: s)
        }
    }
}

// MARK: - Background composition (vertical-only)

/// Two-layer composition for the vertical Heritage ticket:
///   • back: bg-coloured rectangle masked through the envelope shape.
///   • front: plane silhouette in `planeFill`, even-odd-filled so the
///     28 perforation circles render as transparent cutouts.
private struct HeritageVerticalBackground: View {
    var surfaceFill: Color
    var planeFill: Color
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {

            HeritageVerticalEnvelope()
                .fill(surfaceFill, style: FillStyle(eoFill: true))
                .frame(width: width, height: height)
            

            HeritageVerticalPlaneShape()
                .fill(planeFill, style: FillStyle(eoFill: true))
                .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Vertical envelope

/// Vertical ticket silhouette ported from the Figma `stub-1` SVG and
/// rotated 90° clockwise into 260×455 space. Tab notches sit on the
/// LEFT and RIGHT edges around y=74; perforations form a horizontal
/// row across the same y. Even-odd fill turns each perforation
/// circle into a transparent hole.
private struct HeritageVerticalEnvelope: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 260
        let sy = rect.height / 455
        // Map horizontal (x_h, y_h) in 455×260 space onto vertical
        // (y_h, 455 − x_h) — 90° counter-clockwise rotation. Wing
        // tip points UP at top-centre; perforation row + tab
        // notches land at y≈381 so the stub sits at the BOTTOM
        // of the ticket.
        func vpt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: y * sx, y: (455 - x) * sy)
        }
        var p = Path()
        p.move(to: vpt(455, 236))
        p.addCurve(to: vpt(431, 260),
                   control1: vpt(455, 249.255),
                   control2: vpt(444.255, 260))
        p.addLine(to: vpt(225.78, 260))
        p.addLine(to: vpt(90, 260))
        // Right-edge tab (was top tab in horizontal).
        p.addCurve(to: vpt(74, 244),
                   control1: vpt(90, 251.163),
                   control2: vpt(82.8366, 244))
        p.addCurve(to: vpt(58, 260),
                   control1: vpt(65.1634, 244),
                   control2: vpt(58, 251.163))
        p.addLine(to: vpt(24, 260))
        p.addCurve(to: vpt(0, 236),
                   control1: vpt(10.7452, 260),
                   control2: vpt(0, 249.255))
        p.addLine(to: vpt(0, 24))
        p.addCurve(to: vpt(24, 0),
                   control1: vpt(0, 10.7452),
                   control2: vpt(10.7452, 0))
        p.addLine(to: vpt(58, 0))
        // Left-edge tab (was bottom tab in horizontal).
        p.addCurve(to: vpt(74, 16),
                   control1: vpt(58, 8.83656),
                   control2: vpt(65.1635, 16))
        p.addCurve(to: vpt(90, 0),
                   control1: vpt(82.8366, 16),
                   control2: vpt(90, 8.83656))
        p.addLine(to: vpt(225.78, 0))
        p.addLine(to: vpt(431, 0))
        p.addCurve(to: vpt(455, 24),
                   control1: vpt(444.255, 0),
                   control2: vpt(455, 10.7452))
        p.addLine(to: vpt(455, 236))
        p.closeSubpath()

        // 28 perforation circles. Horizontal had them at (74, 22+8k);
        // rotated to (260 − cy, 74) on the vertical canvas.
        for k in 0..<28 {
            let cy: CGFloat = 22 + CGFloat(k) * 8
            let center = vpt(74, cy)
            p.addEllipse(in: CGRect(
                x: center.x - 2 * sx,
                y: center.y - 2 * sy,
                width: 4 * sx,
                height: 4 * sy
            ))
        }
        return p
    }
}

// MARK: - Vertical plane silhouette

/// Plane silhouette rotated 90° CW. Wing tip points DOWN; left
/// rounded corners (in horizontal) become TOP rounded corners; tab
/// notches sit on the left + right edges around y=74; perforation
/// row at y=74 cuts across.
private struct HeritageVerticalPlaneShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 260
        let sy = rect.height / 455
        // Same 90° CCW mapping as `HeritageVerticalEnvelope` —
        // wing tip points UP, stub at the bottom.
        func vpt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: y * sx, y: (455 - x) * sy)
        }
        var p = Path()
        // Outline — same as `heritagePlaneOutline` in the horizontal
        // file, with every coordinate routed through `vpt`.
        p.move(to: vpt(432, 130))
        p.addCurve(to: vpt(425.751, 143.341),
                   control1: vpt(431.905, 134.92),
                   control2: vpt(429.822, 139.367))
        p.addCurve(to: vpt(409.418, 152.565),
                   control1: vpt(421.68, 147.22),
                   control2: vpt(416.235, 150.295))
        p.addCurve(to: vpt(387.12, 155.83),
                   control1: vpt(402.695, 154.742),
                   control2: vpt(395.263, 155.83))
        p.addLine(to: vpt(335.565, 155.83))
        p.addCurve(to: vpt(327.328, 157.107),
                   control1: vpt(331.968, 155.83),
                   control2: vpt(329.222, 156.256))
        p.addCurve(to: vpt(321.505, 161.79),
                   control1: vpt(325.529, 157.864),
                   control2: vpt(323.588, 159.425))
        p.addLine(to: vpt(235.58, 255.459))
        p.addCurve(to: vpt(225.78, 260),
                   control1: vpt(232.834, 258.487),
                   control2: vpt(229.568, 260))
        p.addLine(to: vpt(90, 260))
        p.addCurve(to: vpt(74, 244),
                   control1: vpt(90, 251.163),
                   control2: vpt(82.8366, 244))
        p.addCurve(to: vpt(58, 260),
                   control1: vpt(65.1634, 244),
                   control2: vpt(58, 251.163))
        p.addLine(to: vpt(24, 260))
        p.addCurve(to: vpt(0, 236),
                   control1: vpt(10.7452, 260),
                   control2: vpt(0, 249.255))
        p.addLine(to: vpt(0, 24))
        p.addCurve(to: vpt(24, 0),
                   control1: vpt(0, 10.7452),
                   control2: vpt(10.7452, 0))
        p.addLine(to: vpt(58, 0))
        p.addCurve(to: vpt(74, 16),
                   control1: vpt(58, 8.83656),
                   control2: vpt(65.1635, 16))
        p.addCurve(to: vpt(90, 0),
                   control1: vpt(82.8366, 16),
                   control2: vpt(90, 8.83656))
        p.addLine(to: vpt(225.78, 0))
        p.addCurve(to: vpt(235.58, 4.54102),
                   control1: vpt(229.568, 0),
                   control2: vpt(232.834, 1.51351))
        p.addLine(to: vpt(321.505, 98.21))
        p.addCurve(to: vpt(327.328, 103.177),
                   control1: vpt(323.588, 100.67),
                   control2: vpt(325.529, 102.325))
        p.addCurve(to: vpt(335.565, 104.313),
                   control1: vpt(329.222, 103.934),
                   control2: vpt(331.968, 104.313))
        p.addLine(to: vpt(387.12, 104.313))
        p.addCurve(to: vpt(409.418, 107.719),
                   control1: vpt(395.263, 104.313),
                   control2: vpt(402.695, 105.448))
        p.addCurve(to: vpt(425.751, 116.802),
                   control1: vpt(416.235, 109.895),
                   control2: vpt(421.68, 112.923))
        p.addCurve(to: vpt(432, 130),
                   control1: vpt(429.822, 120.681),
                   control2: vpt(431.905, 125.08))
        p.closeSubpath()

        // 28 perforation cutouts at horizontal (74, 22+8k).
        for k in 0..<28 {
            let cy: CGFloat = 22 + CGFloat(k) * 8
            let center = vpt(74, cy)
            p.addEllipse(in: CGRect(
                x: center.x - 2 * sx,
                y: center.y - 2 * sy,
                width: 4 * sx,
                height: 4 * sy
            ))
        }
        return p
    }
}

// MARK: - Preview

#Preview {
    HeritageTicketVerticalView(ticket: HeritageTicket(
        airline: "Airline",
        ticketNumber: "Ticket number · Aircraft",
        cabinClass: "Class",
        cabinDetail: "Business · The Pier",
        origin: "HKG",
        originName: "Hong Kong International",
        originLocation: "Hong Kong",
        destination: "LHR",
        destinationName: "London Heathrow",
        destinationLocation: "London, United Kingdom",
        flightDuration: "9h 40m · Non-stop",
        gate: "42",
        seat: "11A",
        boardingTime: "22:10",
        departureTime: "22:55",
        date: "4 Sep",
        fullDate: "4 Sep 2026"
    ))
    .padding(24)
    .background(Color.Background.default)
}
