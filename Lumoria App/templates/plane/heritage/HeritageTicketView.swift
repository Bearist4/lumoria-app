//
//  HeritageTicketView.swift
//  Lumoria App
//
//  Horizontal boarding-pass card for the "Heritage" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=1-2221
//

import SwiftUI

// MARK: - Model

struct HeritageTicket: Codable, Hashable {
    var airline: String                 // "Airline"
    var ticketNumber: String            // "Ticket number · Aircraft"
    var cabinClass: String              // "Class"
    var cabinDetail: String             // "Business · The Pier"
    var origin: String                  // "HKG"
    var originName: String              // "Hong Kong International"
    var originLocation: String          // "Hong Kong"
    var destination: String             // "LHR"
    var destinationName: String         // "London Heathrow"
    var destinationLocation: String     // "London, United Kingdom"
    var flightDuration: String          // "9h 40m · Non-stop"
    var gate: String                    // "42"
    var seat: String                    // "11A"
    var boardingTime: String            // "22:10"
    var departureTime: String           // "22:55"
    var date: String                    // "4 Sep"
    var fullDate: String                // "4 Sep 2026"
}

// MARK: - View

struct HeritageTicketView: View {
    let ticket: HeritageTicket
    var style: TicketStyleVariant = TicketTemplateKind.heritage.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260
    private let stubWidth: CGFloat = 74

    /// 4-step palette derived from `style.accent`. Each ticket region
    /// reads from the matching shade so a single user pick recolours
    /// the whole template coherently.
    private var ramp: HeritageRamp { HeritageRamp(base: style.accent) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .topLeading) {
                // Plane silhouette + perforation strip — drawn in code
                // from the Figma SVG. Coordinates rescaled to 455×260
                // so the plane's left corners, tab notches, and
                // perforation column line up exactly with the
                // envelope's. Perforations are even-odd cutouts —
                // transparent through the plane.
                HeritageBackground(
                    surfaceFill: style.backgroundColor ?? .white,
                    planeFill: ramp.shade100,
                    width: w,
                    height: h
                )
                .styleAnchor(.accent)

                // Background anchor — sits on the perforation strip so
                // the preview pill points at where the user's pick is
                // visible (through the plane's circle cutouts).
                Color.clear
                    .frame(width: 4 * s, height: (240 - 22) * s)
                    .offset(x: 72 * s, y: 22 * s)
                    .styleAnchor(.background)

                stubColumn(scale: s)
                    .frame(width: stubWidth * s, height: h)

                VStack(spacing: 0) {
                    headerRow(scale: s)
                    Spacer(minLength: 0)
                    routeRow(scale: s)
                    Spacer(minLength: 0)
                    footerRow(scale: s)
                }
                .frame(width: (455 - stubWidth) * s, height: h)
                .offset(x: stubWidth * s, y: 0)
            }
            .frame(width: w, height: h)
            // Final outer clip — uses the same `HeritageTicketEnvelope`
            // shape as the bg layer's mask. Pure SwiftUI Path, so it
            // reads alpha reliably (the PDF asset version was cropping
            // everything away in some build configurations).
            .clipShape(HeritageTicketEnvelope(),
                       style: FillStyle(eoFill: true))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Rotated stub column (left 74pt)

    private func stubColumn(scale s: CGFloat) -> some View {
        // Unrotated content block sized 260x74; rotated 90° clockwise fills 74x260.
        let cw: CGFloat = 260 * s
        let ch: CGFloat = stubWidth * s

        return ZStack {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4 * s) {
                    Text("\(ticket.origin) → \(ticket.destination)")
                        .font(.system(size: 8 * s, weight: .bold))
                        .foregroundStyle(style.textPrimary.opacity(0.6))

                    Text(ticket.fullDate)
                        .font(.system(size: 10 * s, weight: .bold))
                        .foregroundStyle(style.textPrimary.opacity(0.4))

                    Text(ticket.cabinClass.uppercased())
                        .font(.system(size: 6 * s, weight: .bold))
                        .tracking(2 * s)
                        .foregroundStyle(style.textPrimary.opacity(0.4))
                }

                Spacer(minLength: 0)

                madeWithBadge(scale: s)
            }
            .padding(.horizontal, 16 * s)
            .padding(.vertical, 12 * s)
            .frame(width: cw, height: ch)
        }
        .frame(width: cw, height: ch)
        .rotationEffect(.degrees(-90))
        .frame(width: ch, height: cw)
    }

    // MARK: - Header row

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
        .padding(.horizontal, 24 * s)
        .padding(.vertical, 16 * s)
    }

    // MARK: - Route row

    private func routeRow(scale s: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            airportBlock(
                code: ticket.origin,
                name: ticket.originName,
                location: ticket.originLocation,
                codeColor: ramp.shade500,
                alignment: .leading,
                scale: s
            )

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                Text(verbatim: "→")
                    .font(.custom("Georgia", size: 12.235 * s))
                    .foregroundStyle(style.textPrimary)

                Text(ticket.flightDuration.uppercased())
                    .font(.system(size: 5.35 * s, weight: .bold))
                    .tracking(1.18 * s)
                    .foregroundStyle(style.textPrimary)
            }

            Spacer(minLength: 0)

            airportBlock(
                code: ticket.destination,
                name: ticket.destinationName,
                location: ticket.destinationLocation,
                codeColor: ramp.shade700,
                alignment: .trailing,
                scale: s
            )
        }
        .padding(.horizontal, 24 * s)
    }

    private func airportBlock(
        code: String,
        name: String,
        location: String,
        codeColor: Color,
        alignment: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        let textAlign: TextAlignment = (alignment == .leading) ? .leading : .trailing
        return VStack(alignment: alignment, spacing: 4 * s) {
            Text(code)
                .font(.custom("Georgia-Bold", size: 48 * s))
                .foregroundStyle(codeColor)
                .blendMode(.multiply)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            // Anchor only the destination (right) airport name — one
            // anchor is enough for the preview pill, and the right
            // side leaves the most room for a leader without crossing.
            Group {
                if alignment == .trailing {
                    Text(name).styleAnchor(.textPrimary)
                } else {
                    Text(name)
                }
            }
            .font(.system(size: 8 * s, weight: .bold))
            .foregroundStyle(style.textPrimary)
            .multilineTextAlignment(textAlign)
            .lineLimit(1)

            Text(location.uppercased())
                .font(.system(size: 6 * s, weight: .regular))
                .tracking(0.5 * s)
                .foregroundStyle(style.textPrimary.opacity(0.4))
                .multilineTextAlignment(textAlign)
                .lineLimit(1)
        }
    }

    // MARK: - Footer 5-cell row

    private func footerRow(scale s: CGFloat) -> some View {
        HStack(spacing: 0) {
            detailCell(label: "Gate",    value: ticket.gate,          showDivider: false, scale: s)
            detailCell(label: "Seat",    value: ticket.seat,          showDivider: true,  scale: s)
            detailCell(label: "Boards",  value: ticket.boardingTime,  showDivider: true,  scale: s)
            detailCell(label: "Departs", value: ticket.departureTime, showDivider: true,  scale: s)
            detailCell(label: "Date",    value: ticket.date,          showDivider: true,  scale: s)
        }
        .padding(.horizontal, 24 * s)
        .padding(.vertical, 8 * s)
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

    // MARK: - Made with Lumoria badge

    @ViewBuilder
    private func madeWithBadge(scale s: CGFloat) -> some View {
        if showsLumoriaWatermark {
            MadeWithLumoria(style: .black, version: .small, scale: s)
        }
    }
}

// MARK: - Accent ramp

/// 4-step palette derived from a single user-picked accent. Mirrors
/// the Figma `Color/100`, `400`, `500`, `700` shades by interpolating
/// the base toward white (lighter steps) or black (darker step).
/// Hue stays put — only luminance shifts — so any base colour the
/// user picks produces a coherent set across the ticket.
struct HeritageRamp {
    let shade100: Color  // plane silhouette tint
    let shade400: Color  // airline label + cabin pill bg
    let shade500: Color  // origin code + footer cell labels
    let shade700: Color  // ticket number + destination code

    init(base: Color) {
        self.shade100 = base.mixed(with: .white, by: 0.80)
        self.shade400 = base.mixed(with: .white, by: 0.15)
        self.shade500 = base
        self.shade700 = base.mixed(with: .black, by: 0.45)
    }
}

// MARK: - Plane silhouette (ported from Figma SVG)

/// Two-layer plane render:
///   • back: ticket envelope (paper around the plane) filled with
///     `surfaceFill`. The shape comes from the `stub-1` asset, which
///     is the ticket paper silhouette MINUS the plane area MINUS the
///     perforation cutouts — so perforations stay translucent.
///   • front: plane outline + 28 circle cutouts filled with `planeFill`
///     using the even-odd rule, so the perforation discs punch
///     transparent holes through the plane too.
/// The user's "Background" pick drives `surfaceFill`; the accent ramp's
/// shade100 drives `planeFill`.
private struct HeritageBackground: View {
    var surfaceFill: Color
    var planeFill: Color
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {

            HeritageTicketEnvelope()
                .fill(surfaceFill, style: FillStyle(eoFill: true))
                .frame(width: width, height: height)
                

            HeritagePlaneShape()
                .fill(planeFill, style: FillStyle(eoFill: true))
                .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
    }
}

private struct HeritageTicketEnvelope: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 455
        let sy = rect.height / 260
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }
        var p = Path()
        // Start: bottom-right (mirroring the SVG's M 455 236).
        p.move(to: pt(455, 236))
        // Bottom-right rounded corner.
        p.addCurve(to: pt(431, 260),
                   control1: pt(455, 249.255),
                   control2: pt(444.255, 260))
        // Bottom edge to bottom tab.
        p.addLine(to: pt(225.78, 260))
        p.addLine(to: pt(90, 260))
        // Bottom tab semicircle (notch dipping up into the ticket).
        p.addCurve(to: pt(74, 244),
                   control1: pt(90, 251.163),
                   control2: pt(82.8366, 244))
        p.addCurve(to: pt(58, 260),
                   control1: pt(65.1634, 244),
                   control2: pt(58, 251.163))
        // Bottom edge to bottom-left corner.
        p.addLine(to: pt(24, 260))
        p.addCurve(to: pt(0, 236),
                   control1: pt(10.7452, 260),
                   control2: pt(0, 249.255))
        // Left edge.
        p.addLine(to: pt(0, 24))
        // Top-left rounded corner.
        p.addCurve(to: pt(24, 0),
                   control1: pt(0, 10.7452),
                   control2: pt(10.7452, 0))
        // Top edge to top tab.
        p.addLine(to: pt(58, 0))
        // Top tab semicircle (notch dipping down into the ticket).
        p.addCurve(to: pt(74, 16),
                   control1: pt(58, 8.83656),
                   control2: pt(65.1635, 16))
        p.addCurve(to: pt(90, 0),
                   control1: pt(82.8366, 16),
                   control2: pt(90, 8.83656))
        // Top edge to top-right corner.
        p.addLine(to: pt(225.78, 0))
        p.addLine(to: pt(431, 0))
        p.addCurve(to: pt(455, 24),
                   control1: pt(444.255, 0),
                   control2: pt(455, 10.7452))
        // Right edge back to start.
        p.addLine(to: pt(455, 236))
        p.closeSubpath()

        // 28 perforation circles at (cx=74, cy=22+8k), radius 2pt.
        // Even-odd fill turns each into a transparent cutout.
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

/// Plane silhouette + 28 circle cutouts as one path (viewBox 432×260).
/// Outline transcribed verbatim from the Figma export. Each circle
/// adds a closed subpath so even-odd filling treats the disc as a
/// transparent hole. `path(in:)` rescales every coordinate to the
/// rect the caller supplies.
private struct HeritagePlaneShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Use 455-wide coord space (matching the envelope) so the
        // plane's left rounded corners, tab notches, and perforation
        // column line up pixel-perfect with the envelope's. Wing tip
        // stays at its native x=432 — leaves a 23pt gap before the
        // envelope's right edge, exactly as the SVG was authored.
        let sx = rect.width / 455
        let sy = rect.height / 260
        var p = heritagePlaneOutline(in: rect)
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

/// Shared outline construction — used by both the solid back layer
/// and the front layer that adds perforation cutouts on top.
/// Coordinates use 455×260 space so they line up with the envelope's
/// (`HeritageTicketEnvelope`) — same x for rounded corners on the
/// left, tab notches around x=74, and the perforation column.
private func heritagePlaneOutline(in rect: CGRect) -> Path {
    let sx = rect.width / 455
    let sy = rect.height / 260
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * sx, y: y * sy)
    }
    var p = Path()
    p.move(to: pt(432, 130))
        // Wing tip → upper rear of wing.
        p.addCurve(to: pt(425.751, 143.341),
                   control1: pt(431.905, 134.92), control2: pt(429.822, 139.367))
        p.addCurve(to: pt(409.418, 152.565),
                   control1: pt(421.68, 147.22), control2: pt(416.235, 150.295))
        p.addCurve(to: pt(387.12, 155.83),
                   control1: pt(402.695, 154.742), control2: pt(395.263, 155.83))
        // Top of wing root → fuselage rear.
        p.addLine(to: pt(335.565, 155.83))
        p.addCurve(to: pt(327.328, 157.107),
                   control1: pt(331.968, 155.83), control2: pt(329.222, 156.256))
        p.addCurve(to: pt(321.505, 161.79),
                   control1: pt(325.529, 157.864), control2: pt(323.588, 159.425))
        // Diagonal down-left to bottom-edge of fuselage.
        p.addLine(to: pt(235.58, 255.459))
        p.addCurve(to: pt(225.78, 260),
                   control1: pt(232.834, 258.487), control2: pt(229.568, 260))
        p.addLine(to: pt(90, 260))
        // Bottom semicircular notch (perforation tab).
        p.addCurve(to: pt(74, 244),
                   control1: pt(90, 251.163), control2: pt(82.8366, 244))
        p.addCurve(to: pt(58, 260),
                   control1: pt(65.1634, 244), control2: pt(58, 251.163))
        p.addLine(to: pt(24, 260))
        // Bottom-left rounded corner.
        p.addCurve(to: pt(0, 236),
                   control1: pt(10.7452, 260), control2: pt(0, 249.255))
        // Left edge.
        p.addLine(to: pt(0, 24))
        // Top-left rounded corner.
        p.addCurve(to: pt(24, 0),
                   control1: pt(0, 10.7452), control2: pt(10.7452, 0))
        p.addLine(to: pt(58, 0))
        // Top semicircular notch (perforation tab).
        p.addCurve(to: pt(74, 16),
                   control1: pt(58, 8.83656), control2: pt(65.1635, 16))
        p.addCurve(to: pt(90, 0),
                   control1: pt(82.8366, 16), control2: pt(90, 8.83656))
        p.addLine(to: pt(225.78, 0))
        // Top fuselage edge.
        p.addCurve(to: pt(235.58, 4.54102),
                   control1: pt(229.568, 0), control2: pt(232.834, 1.51351))
        // Diagonal up-right to top of wing root.
        p.addLine(to: pt(321.505, 98.21))
        p.addCurve(to: pt(327.328, 103.177),
                   control1: pt(323.588, 100.67), control2: pt(325.529, 102.325))
        p.addCurve(to: pt(335.565, 104.313),
                   control1: pt(329.222, 103.934), control2: pt(331.968, 104.313))
        p.addLine(to: pt(387.12, 104.313))
        // Wing leading edge → wing tip.
        p.addCurve(to: pt(409.418, 107.719),
                   control1: pt(395.263, 104.313), control2: pt(402.695, 105.448))
        p.addCurve(to: pt(425.751, 116.802),
                   control1: pt(416.235, 109.895), control2: pt(421.68, 112.923))
        p.addCurve(to: pt(432, 130),
                   control1: pt(429.822, 120.681), control2: pt(431.905, 125.08))
        p.closeSubpath()
        return p
}

// MARK: - Preview

#Preview {
    HeritageTicketView(ticket: HeritageTicket(
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
