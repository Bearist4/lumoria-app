//
//  TerminalTicketVerticalView.swift
//  Lumoria App
//
//  Vertical boarding-pass card for the "Terminal" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=4-869
//
//  Self-contained: envelope + 5 blob shapes + composition view live in
//  this file so the horizontal Terminal stays untouched. Same outer
//  silhouette as Heritage vertical (rounded rect with tab notches and
//  perforation row at y≈381 → stub at the bottom). Five blobs each
//  driven by `tint1..tint5`; bg + text follow `background` +
//  `textPrimary`.
//

import SwiftUI

struct TerminalTicketVerticalView: View {
    let ticket: TerminalTicket
    var style: TicketStyleVariant = TicketTemplateKind.terminal.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack(alignment: .topLeading) {
                // Bg-coloured rectangle masked through the vertical
                // envelope shape — gives the ticket its silhouette
                // + perforation cutouts.
                Rectangle()
                    .fill(style.backgroundColor ?? .black)
                    .frame(width: w, height: h)
                    .mask {
                        TerminalVerticalEnvelope()
                            .fill(style: FillStyle(eoFill: true))
                            .frame(width: w, height: h)
                    }
                    .styleAnchor(.background)

                // Five blobs stacked + heavy-blurred, masked through
                // the same envelope so the colour bleeds off the
                // ticket edges.
                TerminalVerticalBlobs(
                    scale: s,
                    tint1: style.tint1 ?? Color(hex: "303E57"),
                    tint2: style.tint2 ?? Color(hex: "00EAFF"),
                    tint3: style.tint3 ?? Color(hex: "0025CE"),
                    tint4: style.tint4 ?? Color(hex: "BADAFF"),
                    tint5: style.tint5 ?? Color(hex: "4D3589")
                )
                .frame(width: w, height: h)
                .mask {
                    TerminalVerticalEnvelope()
                        .fill(style: FillStyle(eoFill: true))
                        .frame(width: w, height: h)
                }

                // Blob anchor proxies — small 16×16 rects placed at
                // each blob's APPARENT visible centre on the 260×455
                // vertical canvas. Same standard pattern as horizontal
                // Terminal / Prism: outside the masked subtree so
                // `proxy[anchor]` reads accurate per-blob positions.
                ZStack(alignment: .topLeading) {
                    blobAnchor(.tint1, cx:  60 * s, cy: 130 * s)
                    blobAnchor(.tint2, cx: 140 * s, cy: 110 * s)
                    blobAnchor(.tint3, cx: 130 * s, cy: 200 * s)
                    blobAnchor(.tint4, cx: 130 * s, cy: 290 * s)
                    blobAnchor(.tint5, cx: 200 * s, cy: 220 * s)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)

                // Top details row (5 cells: Gate / Seat / Boards / Departs / Date).
                topDetailsRow(scale: s)
                    .frame(width: w)
                    .offset(x: 0, y: 0)

                // Middle route column (CDG stacked above VIE).
                routeColumn(scale: s)
                    .frame(width: w, height: 257 * s)
                    .offset(x: 0, y: 66 * s)

                // Airline + ticket number + Class pill (above perforation).
                airlineRow(scale: s)
                    .frame(width: w)
                    .offset(x: 0, y: 323 * s)

                // Bottom stub (below perforation): flight route + "Made with Lumoria" badge.
                stubRow(scale: s)
                    .frame(width: w, height: 74 * s)
                    .offset(x: 0, y: 381 * s)
            }
            .frame(width: w, height: h)
            // Final outer clip — same envelope shape as the bg layer's
            // mask. Crisp edges against the parent background.
            .clipShape(TerminalVerticalEnvelope(),
                       style: FillStyle(eoFill: true))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Top details row

    private func topDetailsRow(scale s: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            detailCell(label: "Gate",    value: ticket.gate,          scale: s, showDivider: false)
            detailCell(label: "Seat",    value: ticket.seat,          scale: s, showDivider: true)
            detailCell(label: "Boards",  value: ticket.boardingTime,  scale: s, showDivider: true)
            detailCell(label: "Departs", value: ticket.departureTime, scale: s, showDivider: true)
            detailCell(label: "Date",    value: ticket.date,          scale: s, showDivider: true)
        }
        .padding(.horizontal, 12 * s)
        .padding(.vertical, 16 * s)
    }

    private func detailCell(label: String, value: String, scale s: CGFloat, showDivider: Bool) -> some View {
        VStack(spacing: 4 * s) {
            Text(label).textCase(.uppercase)
                .font(.system(size: 4.59 * s, weight: .medium))
                .tracking(1 * s)
                .foregroundStyle(style.textPrimary)

            Text(value)
                .font(.system(size: 9.18 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            if showDivider {
                Rectangle()
                    .fill(style.textPrimary.opacity(0.3))
                    .frame(width: 0.5)
            }
        }
    }

    // MARK: - Route column

    private func routeColumn(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            airportBlock(
                code: ticket.origin,
                name: ticket.originName,
                location: ticket.originLocation,
                anchor: false,
                scale: s
            )

            Spacer(minLength: 0)

            airportBlock(
                code: ticket.destination,
                name: ticket.destinationName,
                location: ticket.destinationLocation,
                anchor: true,
                scale: s
            )
        }
        .padding(.horizontal, 24 * s)
    }

    private func airportBlock(
        code: String,
        name: String,
        location: String,
        anchor: Bool,
        scale s: CGFloat
    ) -> some View {
        VStack(spacing: 4 * s) {
            // Anchor only the destination block — single .textPrimary
            // anchor for the preview pill.
            Group {
                if anchor {
                    Text(code).styleAnchor(.textPrimary)
                } else {
                    Text(code)
                }
            }
            .font(.custom("Doto-Black", size: 64 * s))
            .foregroundStyle(style.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            Text(name)
                .font(.system(size: 8 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)

            Text(location.uppercased())
                .font(.system(size: 6 * s, weight: .regular))
                .tracking(0.5 * s)
                .foregroundStyle(style.textPrimary.opacity(0.4))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Airline / ticket / class row

    private func airlineRow(scale s: CGFloat) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4 * s) {
                Text(ticket.airline.uppercased())
                    .font(.system(size: 8 * s, weight: .bold))
                    .tracking(1.5 * s)
                    .foregroundStyle(style.textPrimary.opacity(0.55))

                Text(ticket.ticketNumber)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(0.5 * s)
                    .foregroundStyle(style.textPrimary)
            }

            Spacer()

            Text(ticket.cabinClass.uppercased())
                .font(.system(size: 6 * s, weight: .bold))
                .tracking(0.64 * s)
                .foregroundStyle(style.textPrimary)
                .styleAnchor(.onAccent)
                .padding(.horizontal, 8 * s)
                .padding(.vertical, 4 * s)
                .background(
                    RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
                        .fill(style.textPrimary.opacity(0.35))
                )
        }
        .padding(.horizontal, 24 * s)
        .padding(.vertical, 16 * s)
    }

    // MARK: - Bottom stub (below perforation)

    private func stubRow(scale s: CGFloat) -> some View {
        let routeCode = "\(ticket.origin) → \(ticket.destination)"

        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4 * s) {
                Text(routeCode)
                    .font(.custom("Doto-Black", size: 12 * s))
                .foregroundStyle(style.textPrimary.opacity(0.9))

                Text(ticket.fullDate)
                    .font(.system(size: 10 * s, weight: .bold))
                    .foregroundStyle(style.textPrimary.opacity(0.6))

                Text(ticket.cabinClass.uppercased())
                    .font(.system(size: 6 * s, weight: .bold))
                    .tracking(2 * s)
                    .foregroundStyle(style.textPrimary.opacity(0.6))
            }

            Spacer(minLength: 0)

            stubBadge(scale: s)
        }
        .padding(.horizontal, 16 * s)
        .padding(.vertical, 12 * s)
    }

    @ViewBuilder
    private func stubBadge(scale s: CGFloat) -> some View {
        if showsLumoriaWatermark {
            // Black-style badge on Terminal's dark stub.
            MadeWithLumoria(style: .black, version: .small, scale: s)
        }
    }

    // MARK: - Standardised blob anchor

    /// Same pattern as horizontal Terminal / Prism — small 16×16
    /// rect at the chosen visible centre so the StyleStep pill
    /// leader lands exactly at (cx, cy).
    private func blobAnchor(
        _ element: TicketStyleVariant.Element,
        cx: CGFloat,
        cy: CGFloat
    ) -> some View {
        Color.clear
            .frame(width: 16, height: 16)
            .styleAnchor(element)
            .offset(x: cx - 8, y: cy - 8)
    }
}

// MARK: - Aurora blobs (vertical Terminal)

/// Same five blob shapes as the horizontal Terminal export, placed
/// at vertical-canvas-equivalent positions. ViewBoxes and blur radii
/// match the horizontal export exactly; only (x, y) offsets are
/// rebased for the 260×455 vertical canvas.
private struct TerminalVerticalBlobs: View {
    let scale: CGFloat
    let tint1: Color
    let tint2: Color
    let tint3: Color
    let tint4: Color
    let tint5: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Blob 1 — viewBox 155×235, blur 31.16, vertical pos (−50, 30).
            VTerminalBlob1()
                .fill(tint1)
                .frame(width: 155 * scale, height: 235 * scale)
                .blur(radius: 31.1633 * scale)
                .offset(x: 80 * scale, y: 20 * scale)

            // Blob 2 — viewBox 251×204, blur 20.78, vertical pos (10, 80).
            VTerminalBlob2()
                .fill(tint2)
                .frame(width: 251 * scale, height: 204 * scale)
                .blur(radius: 20.7755 * scale)
                .offset(x: 75 * scale, y: 100 * scale)

            // Blob 3 — viewBox 309×205, rotated ellipse (10.54° internal),
            // blur 41.55, vertical pos (-30, 150).
            VTerminalBlob3(scale: scale)
                .fill(tint3)
                .blur(radius: 41.5511 * scale)
                .offset(x: 75 * scale, y: 150 * scale)

            // Blob 4 — viewBox 444×118, blur 20.78, vertical pos (-100, 270).
            VTerminalBlob4()
                .fill(tint4)
                .frame(width: 444 * scale, height: 118 * scale)
                .blur(radius: 20.7755 * scale)
                .offset(x: 200 * scale, y: 190 * scale)

            // Blob 5 — viewBox 347×188, blur 31.16, vertical pos (-50, 180).
            VTerminalBlob5()
                .fill(tint5)
                .frame(width: 347 * scale, height: 188 * scale)
                .blur(radius: 31.1633 * scale)
                .offset(x: 0 * scale, y: 180 * scale)
        }
    }
}

// MARK: - Blob shapes (vertical — same paths as horizontal)

private struct VTerminalBlob1: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 155
        let sy = rect.height / 235
        let rx = 61.3917 * sx
        let ry = 55.0551 * sy
        return Path(ellipseIn: CGRect(
            x: 30.4522 * sx - rx,
            y: 117.382 * sy - ry,
            width: rx * 2,
            height: ry * 2
        ))
    }
}

private struct VTerminalBlob2: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 251
        let sy = rect.height / 204
        var p = Path()
        p.move(to: CGPoint(x: 192.605 * sx, y: 154.116 * sy))
        p.addCurve(to: CGPoint(x: 0.22385 * sx, y: 41.6163 * sy),
                   control1: CGPoint(x: 76.4164 * sx, y: 147.984 * sy),
                   control2: CGPoint(x: 40.6323 * sx, y: 38.5 * sy))
        p.addCurve(to: CGPoint(x: 0.22385 * sx, y: 187.357 * sy),
                   control1: CGPoint(x: -50.5723 * sx, y: 45.5337 * sy),
                   control2: CGPoint(x: -41.1078 * sx, y: 148.228 * sy))
        p.addCurve(to: CGPoint(x: 192.605 * sx, y: 154.116 * sy),
                   control1: CGPoint(x: 48.9425 * sx, y: 233.478 * sy),
                   control2: CGPoint(x: 271.344 * sx, y: 158.271 * sy))
        p.closeSubpath()
        return p
    }
}

/// Blob 3 — rotated ellipse wrapper. Same approach as horizontal.
private struct VTerminalBlob3: View {
    let scale: CGFloat

    var body: some View {
        Ellipse()
            .frame(width: 270.842 * scale, height: 143.298 * scale)
            .rotationEffect(.degrees(10.5409))
            .offset(
                x: (91.2429 - 135.421) * scale,
                y: (157.792 - 71.649) * scale
            )
            .frame(width: 309 * scale, height: 205 * scale, alignment: .topLeading)
    }

    func fill(_ color: Color) -> some View {
        Ellipse()
            .fill(color)
            .frame(width: 270.842 * scale, height: 143.298 * scale)
            .rotationEffect(.degrees(10.5409))
            .offset(
                x: (91.2429 - 135.421) * scale,
                y: (157.792 - 71.649) * scale
            )
            .frame(width: 309 * scale, height: 205 * scale, alignment: .topLeading)
    }
}

private struct VTerminalBlob4: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 444
        let sy = rect.height / 118
        var p = Path()
        p.move(to: CGPoint(x: 67.952 * sx, y: 76.7574 * sy))
        p.addCurve(to: CGPoint(x: 15.4938 * sx, y: 121.321 * sy),
                   control1: CGPoint(x: 32.268 * sx, y: 76.7574 * sy),
                   control2: CGPoint(x: 15.4938 * sx, y: 95.7327 * sy))
        p.addCurve(to: CGPoint(x: 378.185 * sx, y: 149.172 * sy),
                   control1: CGPoint(x: 15.4938 * sx, y: 174.714 * sy),
                   control2: CGPoint(x: 330.485 * sx, y: 193.698 * sy))
        p.addCurve(to: CGPoint(x: 371.794 * sx, y: 54.0082 * sy),
                   control1: CGPoint(x: 413.241 * sx, y: 116.448 * sy),
                   control2: CGPoint(x: 408.746 * sx, y: 70.3699 * sy))
        p.addCurve(to: CGPoint(x: 263.45 * sx, y: 54.0081 * sy),
                   control1: CGPoint(x: 330.035 * sx, y: 35.518 * sy),
                   control2: CGPoint(x: 304.477 * sx, y: 39.3919 * sy))
        p.addCurve(to: CGPoint(x: 180.451 * sx, y: 87.9761 * sy),
                   control1: CGPoint(x: 229.217 * sx, y: 66.2036 * sy),
                   control2: CGPoint(x: 218.068 * sx, y: 77.6915 * sy))
        p.addCurve(to: CGPoint(x: 67.952 * sx, y: 76.7574 * sy),
                   control1: CGPoint(x: 145.242 * sx, y: 97.6025 * sy),
                   control2: CGPoint(x: 99.6485 * sx, y: 76.7574 * sy))
        p.closeSubpath()
        return p
    }
}

private struct VTerminalBlob5: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 347
        let sy = rect.height / 188
        let rx = 141.897 * sx
        let ry = 129.432 * sy
        return Path(ellipseIn: CGRect(
            x: 204.223 * sx - rx,
            y: 191.758 * sy - ry,
            width: rx * 2,
            height: ry * 2
        ))
    }
}

// MARK: - Vertical envelope

/// Vertical version of the horizontal Terminal envelope. 90° CCW
/// rotation of the same SVG path — wing-less rounded rect with tab
/// notches on the LEFT/RIGHT edges around y=381 and a perforation
/// row across at y=381. Stub area at the bottom (y=381..455).
private struct TerminalVerticalEnvelope: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 260
        let sy = rect.height / 455
        // Map horizontal (x_h, y_h) in 455×260 onto vertical
        // (y_h, 455 − x_h). 90° CCW rotation → stub at bottom.
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
        p.addLine(to: vpt(431, 0))
        p.addCurve(to: vpt(455, 24),
                   control1: vpt(444.255, 0),
                   control2: vpt(455, 10.7452))
        p.addLine(to: vpt(455, 236))
        p.closeSubpath()

        // 28 perforation circles at horizontal (74, 22+8k) → vertical
        // positions at y=381 spanning x=22..234.
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
    TerminalTicketVerticalView(ticket: TerminalTicket(
        airline: "Airline",
        ticketNumber: "Ticket number",
        cabinClass: "Business",
        origin: "CDG",
        originName: "Charles De Gaulle",
        originLocation: "Paris, France",
        destination: "VIE",
        destinationName: "Vienna International",
        destinationLocation: "Vienna, Austria",
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
