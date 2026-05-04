//
//  TerminalTicketView.swift
//  Lumoria App
//
//  Horizontal boarding-pass card for the "Terminal" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=4-724
//
//  Self-contained: envelope + 5 blob shapes + composition view live
//  in this file so the Heritage horizontal stays untouched. Same
//  outer silhouette as Heritage (rounded rect with tab notches and
//  perforation column at x=74); the visual differentiator is a
//  five-blob aurora field, each blob driven by its own style slot
//  (`tint1..tint5`).
//

import SwiftUI

// MARK: - Model

struct TerminalTicket: Codable, Hashable {
    var airline: String                 // "Airline"
    var ticketNumber: String            // "Ticket number"
    var cabinClass: String              // "Business"
    var origin: String                  // "CDG"
    var originName: String              // "Charles De Gaulle"
    var originLocation: String          // "Paris, France"
    var destination: String             // "VIE"
    var destinationName: String         // "Vienna International"
    var destinationLocation: String     // "Vienna, Austria"
    var gate: String                    // "42"
    var seat: String                    // "11A"
    var boardingTime: String            // "22:10"
    var departureTime: String           // "22:55"
    var date: String                    // "4 Sep"
    var fullDate: String                // "4 Sep 2026"
}

// MARK: - View

struct TerminalTicketView: View {
    let ticket: TerminalTicket
    var style: TicketStyleVariant = TicketTemplateKind.terminal.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260
    private let stubWidth: CGFloat = 74

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .topLeading) {
                // Bg-coloured rectangle masked through the envelope
                // shape — gives the ticket its silhouette + perforation
                // cutouts.
                Rectangle()
                    .fill(style.backgroundColor ?? .black)
                    .frame(width: w, height: h)
                    .mask {
                        TerminalEnvelope()
                            .fill(style: FillStyle(eoFill: true))
                            .frame(width: w, height: h)
                    }
                    .styleAnchor(.background)

                // Five blobs stacked + heavy-blurred, then masked
                // through the same envelope so the colour bleeds
                // straight off the ticket edges.
                TerminalBlobs(
                    scale: s,
                    tint1: style.tint1 ?? Color(hex: "303E57"),
                    tint2: style.tint2 ?? Color(hex: "00EAFF"),
                    tint3: style.tint3 ?? Color(hex: "0025CE"),
                    tint4: style.tint4 ?? Color(hex: "BADAFF"),
                    tint5: style.tint5 ?? Color(hex: "4D3589")
                )
                .frame(width: w, height: h)
                .mask {
                    TerminalEnvelope()
                        .fill(style: FillStyle(eoFill: true))
                        .frame(width: w, height: h)
                }

                // Anchor proxies for each blob — invisible
                // bounding-box-sized rectangles placed at the blob
                // centres via `.offset`. Living in the OUTER ZStack
                // (not inside the masked TerminalBlobs) so the
                // `.styleAnchor` preferences flow up to
                // `StylePreviewTile`'s GeometryProxy and the
                // collision-resolver can place a separate pill per
                // blob without overlap.
                blobAnchors(scale: s)

                // Stub column (rotated text on the left 74pt strip).
                stubColumn(scale: s)
                    .frame(width: stubWidth * s, height: h)

                // Top details row (gate / seat / boards / departs / date).
                topDetailsRow(scale: s)
                    .frame(width: (455 - stubWidth) * s, alignment: .top)
                    .offset(x: stubWidth * s, y: 0)

                // Middle route row (CDG → VIE).
                routeRow(scale: s)
                    .frame(width: (455 - stubWidth) * s, height: 156 * s)
                    .offset(x: stubWidth * s, y: 53 * s)

                // Bottom row (airline / ticket number + class pill).
                bottomRow(scale: s)
                    .frame(width: (455 - stubWidth) * s)
                    .offset(x: stubWidth * s, y: 202 * s)
            }
            .frame(width: w, height: h)
            // Final outer clip — same envelope shape as the bg layer's
            // mask. Crisp edges against the parent background.
            .clipShape(TerminalEnvelope(), style: FillStyle(eoFill: true))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Stub column (rotated 90° clockwise)

    private func stubColumn(scale s: CGFloat) -> some View {
        let routeCode = "\(ticket.origin) → \(ticket.destination)"

        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4 * s) {
                Text(routeCode)
                    .font(.custom("Doto-Black", size: 12 * s))
                    .foregroundStyle(style.textPrimary.opacity(0.6))

                Text(ticket.fullDate)
                    .font(.system(size: 10 * s, weight: .bold))
                    .foregroundStyle(style.textPrimary.opacity(0.4))

                Text(ticket.cabinClass.uppercased())
                    .font(.system(size: 6 * s, weight: .bold))
                    .tracking(2 * s)
                    .foregroundStyle(style.textPrimary.opacity(0.35))
            }

            Spacer(minLength: 0)

            stubBadge(scale: s)
        }
        .padding(.horizontal, 16 * s)
        .padding(.vertical, 12 * s)
        .frame(width: 260 * s, height: 74 * s)
        .rotationEffect(.degrees(90))
    }

    @ViewBuilder
    private func stubBadge(scale s: CGFloat) -> some View {
        if showsLumoriaWatermark {
            MadeWithLumoria(style: .white, version: .small, scale: s)
        }
    }

    // MARK: - Blob anchor proxies

    /// Invisible 16×16 anchor markers placed at each blob's APPARENT
    /// visible centre (clamped inside the 455×260 ticket bounds).
    /// The placement algorithm reads `rect.midX/midY` for the pill
    /// knob — so a small rect at the chosen point makes the leader
    /// land exactly there, regardless of the blob's true bbox
    /// (which often extends well outside the ticket).
    private func blobAnchors(scale s: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Backdrop — dark slate ellipse, visible on the left.
            blobAnchor(.tint1, cx:  20 * s, cy: 175 * s)
            // Glow — cyan path, upper-left.
            blobAnchor(.tint2, cx: 100 * s, cy: 175 * s)
            // Midtone — deep blue rotated ellipse, lower-left.
            blobAnchor(.tint3, cx: 100 * s, cy: 240 * s)
            // Highlight — light blue path across mid-bottom.
            blobAnchor(.tint4, cx: 230 * s, cy: 230 * s)
            // Accent — purple ellipse, right side lower half.
            blobAnchor(.tint5, cx: 350 * s, cy: 230 * s)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

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

    // MARK: - Top details row

    private func topDetailsRow(scale s: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            detailCell(label: "Gate",    value: ticket.gate,         scale: s, showDivider: false)
            detailCell(label: "Seat",    value: ticket.seat,         scale: s, showDivider: true)
            detailCell(label: "Boards",  value: ticket.boardingTime, scale: s, showDivider: true)
            detailCell(label: "Departs", value: ticket.departureTime, scale: s, showDivider: true)
            detailCell(label: "Date",    value: ticket.date,         scale: s, showDivider: true)
        }
        .padding(.horizontal, 24 * s)
        .padding(.vertical, 16 * s)
    }

    private func detailCell(label: String, value: String, scale s: CGFloat, showDivider: Bool) -> some View {
        VStack(spacing: 4 * s) {
            Text(label.uppercased())
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

    // MARK: - Route row

    private func routeRow(scale s: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            airportBlock(
                code: ticket.origin,
                name: ticket.originName,
                location: ticket.originLocation,
                alignment: .leading,
                anchor: false,
                scale: s
            )

            Spacer(minLength: 0)

            airportBlock(
                code: ticket.destination,
                name: ticket.destinationName,
                location: ticket.destinationLocation,
                alignment: .leading,
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
        alignment: HorizontalAlignment,
        anchor: Bool,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: alignment, spacing: 4 * s) {
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
    }

    // MARK: - Bottom row

    private func bottomRow(scale s: CGFloat) -> some View {
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
}

// MARK: - Aurora blobs (terminal)

/// Five Figma-exported blobs stacked + heavy-blurred to recreate the
/// Terminal aurora. Every shape's viewBox / blur / position matches
/// the SVG export exactly. Render order goes back-to-front so the
/// brightest highlights sit on top of the deeper glows.
private struct TerminalBlobs: View {
    let scale: CGFloat
    let tint1: Color   // dark slate ellipse
    let tint2: Color   // cyan blob
    let tint3: Color   // dark blue rotated ellipse
    let tint4: Color   // light blue path
    let tint5: Color   // purple ellipse

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Blob 1 — viewBox 155×235, ellipse cx=30.4522
            // cy=117.382 rx=61.3917 ry=55.0551, position (−30, 64),
            // blur 31.1633.
            TerminalBlob1()
                .fill(tint1)
                .frame(width: 155 * scale, height: 235 * scale)
                .blur(radius: 20 * scale)
                .offset(x: 0 * scale, y: 0 * scale)

            // Blob 2 — viewBox 251×204, custom path, position (−30, 98),
            // blur 20.7755.
            TerminalBlob2()
                .fill(tint2)
                .frame(width: 251 * scale, height: 204 * scale)
                .blur(radius: 40 * scale)
                .offset(x: -5 * scale, y: 60 * scale)

            // Blob 3 — viewBox 309×205, ellipse cx=91.2429 cy=157.792
            // rx=135.421 ry=71.649 rotated 10.5409°, position (−55,
            // 118), blur 41.5511.
            TerminalBlob3Wrapper(scale: scale)
                .fill(tint3)
                .blur(radius: 45 * scale)
                .offset(x: 100 * scale, y: 60 * scale)

            // Blob 4 — viewBox 444×118, custom path, position (15, 180),
            // blur 20.7755.
            TerminalBlob4()
                .fill(tint4)
                .frame(width: 444 * scale, height: 118 * scale)
                .blur(radius: 45 * scale)
                .offset(x: 0 * scale, y: 140 * scale)

            // Blob 5 — viewBox 347×188, ellipse cx=204.223 cy=191.758
            // rx=141.897 ry=129.432, position (170, 135), blur
            // 31.1633.
            TerminalBlob5()
                .fill(tint5)
                .frame(width: 347 * scale, height: 188 * scale)
                .blur(radius: 60 * scale)
                .offset(x: 230 * scale, y: 80 * scale)
        }
    }
}

// MARK: - Blob shapes

/// Blob 1 — simple ellipse inside its viewBox.
private struct TerminalBlob1: Shape {
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

/// Blob 2 — custom curved path. ViewBox 251×204.
private struct TerminalBlob2: Shape {
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

/// Blob 3 — ellipse rotated 10.5409° around its centre. Wrapped in a
/// view because Path doesn't support per-shape rotation in the same
/// way; we apply `.rotationEffect` to the Ellipse and let SwiftUI
/// handle the transform.
private struct TerminalBlob3Wrapper: View {
    let scale: CGFloat

    var body: some View {
        // ViewBox 309×205, rx=135.421 ry=71.649 → 270.842 × 143.298,
        // centred at (91.2429, 157.792).
        Ellipse()
            .frame(width: 270.842 * scale, height: 143.298 * scale)
            .rotationEffect(.degrees(10.5409))
            .offset(
                x: (91.2429 - 135.421) * scale,
                y: (157.792 - 71.649) * scale
            )
            .frame(width: 309 * scale, height: 205 * scale, alignment: .topLeading)
    }
}

extension TerminalBlob3Wrapper {
    /// Convenience so `TerminalBlobs` can write
    /// `TerminalBlob3Wrapper(scale: s).fill(color)` like the other
    /// blob shapes — wraps the ellipse in a coloured fill.
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

/// Blob 4 — custom curved path. ViewBox 444×118.
private struct TerminalBlob4: Shape {
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

/// Blob 5 — simple ellipse. ViewBox 347×188.
private struct TerminalBlob5: Shape {
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

// MARK: - Envelope (same silhouette as Heritage)

/// Self-contained copy of the canonical ticket envelope so Terminal
/// can use `clipShape` without reaching into the Heritage file.
/// 455×260 rounded rectangle (24pt corners) with two semicircular
/// perforation-tab notches around x=74 and 28 perforation circles.
/// Even-odd fill turns each circle into a transparent hole.
private struct TerminalEnvelope: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 455
        let sy = rect.height / 260
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }
        var p = Path()
        p.move(to: pt(455, 236))
        p.addCurve(to: pt(431, 260),
                   control1: pt(455, 249.255),
                   control2: pt(444.255, 260))
        p.addLine(to: pt(225.78, 260))
        p.addLine(to: pt(90, 260))
        p.addCurve(to: pt(74, 244),
                   control1: pt(90, 251.163),
                   control2: pt(82.8366, 244))
        p.addCurve(to: pt(58, 260),
                   control1: pt(65.1634, 244),
                   control2: pt(58, 251.163))
        p.addLine(to: pt(24, 260))
        p.addCurve(to: pt(0, 236),
                   control1: pt(10.7452, 260),
                   control2: pt(0, 249.255))
        p.addLine(to: pt(0, 24))
        p.addCurve(to: pt(24, 0),
                   control1: pt(0, 10.7452),
                   control2: pt(10.7452, 0))
        p.addLine(to: pt(58, 0))
        p.addCurve(to: pt(74, 16),
                   control1: pt(58, 8.83656),
                   control2: pt(65.1635, 16))
        p.addCurve(to: pt(90, 0),
                   control1: pt(82.8366, 16),
                   control2: pt(90, 8.83656))
        p.addLine(to: pt(225.78, 0))
        p.addLine(to: pt(431, 0))
        p.addCurve(to: pt(455, 24),
                   control1: pt(444.255, 0),
                   control2: pt(455, 10.7452))
        p.addLine(to: pt(455, 236))
        p.closeSubpath()

        // 28 perforation cutouts at (cx=74, cy=22+8k), radius 2pt.
        for k in 0..<28 {
            let cy: CGFloat = 22 + CGFloat(k) * 8
            p.addEllipse(in: CGRect(
                x: 72 * sx,
                y: (cy - 2) * sy,
                width: 4 * sx,
                height: 4 * sy
            ))
        }
        return p
    }
}

// MARK: - Preview

#Preview {
    TerminalTicketView(ticket: TerminalTicket(
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
