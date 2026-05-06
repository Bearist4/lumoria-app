//
//  PrismTicketView.swift
//  Lumoria App
//
//  Horizontal boarding-pass card for the "Prism" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=2-2353
//

import SwiftUI

// MARK: - Model

struct PrismTicket: Codable, Hashable {
    var airline: String             // "Airline"
    var ticketNumber: String        // "Ticket number"
    var date: String                // "16 Aug 2026"
    var origin: String              // "SIN"
    var originName: String          // "Singapore Changi"
    var destination: String         // "HND"
    var destinationName: String     // "Tokyo Haneda"
    var gate: String                // "C34"
    var seat: String                // "11A"
    var boardingTime: String        // "08:40"
    var departureTime: String       // "09:10"
    var terminal: String            // "T3"
}

// MARK: - Aurora image (vertical fallback)

/// Static aurora image used by `PrismTicketVerticalView` until we
/// port the vertical SVG positions. The horizontal view renders
/// `PrismBlobs` in code instead.
struct PrismAurora: View {
    var imageName: String = "prism-gradient"

    var body: some View {
        Image(imageName)
            .resizable()
    }
}

// MARK: - Aurora blobs

/// Three Figma-exported blobs stacked + heavy-blurred to recreate the
/// "Prism" aurora. Coordinates and dimensions ported 1-to-1 from the
/// SVG export — see comments on each shape for the original viewBox.
///
/// Render order (back to front): big magenta → mid hot-pink → small
/// peach. Each carries its own gaussian blur whose radius matches the
/// SVG's `feGaussianBlur stdDeviation`. The composed view sits inside
/// a 455×260 frame so the offsets line up with the ticket canvas.
private struct PrismBlobs: View {
    let scale: CGFloat
    /// Three blob fills sourced from the active style variant — each
    /// falls back to the spec default if the variant didn't ship one.
    /// User overrides on `tint1/tint2/tint3` flow straight through.
    let tint1: Color
    let tint2: Color
    let tint3: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Big blob — viewBox 409×260, position (160, 0).
            PrismBigBlob()
                .fill(tint1)
                .frame(width: 409 * scale, height: 260 * scale)
                .blur(radius: 57.4 * scale)
                .offset(x: 10 * scale, y: 0)

            // Mid blob — viewBox 330×260, position (200, 32).
            PrismMidBlob()
                .fill(tint2)
                .frame(width: 330 * scale, height: 260 * scale)
                .blur(radius: 38.3 * scale)
                .offset(x: 125 * scale, y: 32 * scale)

            // Small ellipse — viewBox 272×260, the SVG rotates the
            // ellipse 21.91° around its centre, then we rotate the
            // whole frame -20° at placement time. Position (236, 45).
            ZStack(alignment: .topLeading) {
                Ellipse()
                    .fill(tint3)
                    .frame(width: 213.002 * scale, height: 145.064 * scale)
                    .rotationEffect(.degrees(21.9106))
                    .offset(
                        x: (179.025 - 213.002 / 2) * scale,
                        y: 40 * scale
                    )
            }
            .frame(width: 272 * scale, height: 260 * scale, alignment: .topLeading)
            .blur(radius: 38.3 * scale)
            .offset(x: 236 * scale, y: 45 * scale)
        }
    }
}

/// SVG path → Swift `Path`. Coordinates use the original 409×260
/// viewBox; `path(in:)` rescales to whatever frame the caller hands in.
private struct PrismBigBlob: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 409
        let sy = rect.height / 260
        var p = Path()
        p.move(to: CGPoint(x: 255.433 * sx, y: 24.724 * sy))
        p.addCurve(to: CGPoint(x: 343.67 * sx, y: 1.16324 * sy),
                   control1: CGPoint(x: 289.992 * sx, y: 15.9066 * sy),
                   control2: CGPoint(x: 308.568 * sx, y: -5.1538 * sy))
        p.addCurve(to: CGPoint(x: 343.67 * sx, y: 212.54 * sy),
                   control1: CGPoint(x: 424.934 * sx, y: 15.7875 * sy),
                   control2: CGPoint(x: 414.421 * sx, y: 169.982 * sy))
        p.addCurve(to: CGPoint(x: 216.452 * sx, y: 212.54 * sy),
                   control1: CGPoint(x: 301.1 * sx, y: 238.147 * sy),
                   control2: CGPoint(x: 261.996 * sx, y: 232.386 * sy))
        p.addCurve(to: CGPoint(x: 130.225 * sx, y: 134.488 * sy),
                   control1: CGPoint(x: 172.018 * sx, y: 193.178 * sy),
                   control2: CGPoint(x: 154.801 * sx, y: 176.255 * sy))
        p.addCurve(to: CGPoint(x: 116.375 * sx, y: 70.3939 * sy),
                   control1: CGPoint(x: 121.29 * sx, y: 119.302 * sy),
                   control2: CGPoint(x: 110.828 * sx, y: 90.8043 * sy))
        p.addCurve(to: CGPoint(x: 164.403 * sx, y: 31.5354 * sy),
                   control1: CGPoint(x: 122.702 * sx, y: 47.1155 * sy),
                   control2: CGPoint(x: 140.751 * sx, y: 36.3079 * sy))
        p.addCurve(to: CGPoint(x: 255.433 * sx, y: 24.724 * sy),
                   control1: CGPoint(x: 188.752 * sx, y: 26.6222 * sy),
                   control2: CGPoint(x: 212.543 * sx, y: 35.6669 * sy))
        p.closeSubpath()
        return p
    }
}

/// SVG path → Swift `Path`. ViewBox 330×260.
private struct PrismMidBlob: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 330
        let sy = rect.height / 260
        var p = Path()
        p.move(to: CGPoint(x: 197.01 * sx, y: 54.1041 * sy))
        p.addCurve(to: CGPoint(x: 272.604 * sx, y: 33.9138 * sy),
                   control1: CGPoint(x: 226.617 * sx, y: 46.5481 * sy),
                   control2: CGPoint(x: 242.531 * sx, y: 28.5005 * sy))
        p.addCurve(to: CGPoint(x: 272.604 * sx, y: 215.052 * sy),
                   control1: CGPoint(x: 342.224 * sx, y: 46.446 * sy),
                   control2: CGPoint(x: 333.217 * sx, y: 178.582 * sy))
        p.addCurve(to: CGPoint(x: 163.615 * sx, y: 215.052 * sy),
                   control1: CGPoint(x: 236.134 * sx, y: 236.996 * sy),
                   control2: CGPoint(x: 202.633 * sx, y: 232.059 * sy))
        p.addCurve(to: CGPoint(x: 89.7433 * sx, y: 148.166 * sy),
                   control1: CGPoint(x: 125.548 * sx, y: 198.46 * sy),
                   control2: CGPoint(x: 110.798 * sx, y: 183.958 * sy))
        p.addCurve(to: CGPoint(x: 77.8779 * sx, y: 93.2407 * sy),
                   control1: CGPoint(x: 82.0882 * sx, y: 135.152 * sy),
                   control2: CGPoint(x: 73.1256 * sx, y: 110.731 * sy))
        p.addCurve(to: CGPoint(x: 119.024 * sx, y: 59.9411 * sy),
                   control1: CGPoint(x: 83.2979 * sx, y: 73.2925 * sy),
                   control2: CGPoint(x: 98.7611 * sx, y: 64.0309 * sy))
        p.addCurve(to: CGPoint(x: 197.01 * sx, y: 54.1041 * sy),
                   control1: CGPoint(x: 139.884 * sx, y: 55.7308 * sy),
                   control2: CGPoint(x: 160.266 * sx, y: 63.4816 * sy))
        p.closeSubpath()
        return p
    }
}

// MARK: - View

struct PrismTicketView: View {
    let ticket: PrismTicket
    var style: TicketStyleVariant = TicketTemplateKind.prism.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark
    @Environment(\.ticketFillsNotchCutouts) private var fillsNotchCutouts

    private let aspectRatio: CGFloat = 455 / 260

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            let bgMask = Image("prism-bg").resizable().frame(width: w, height: h)

            ZStack(alignment: .topLeading) {
                // White paper.
                Rectangle()
                    .fill(style.backgroundColor ?? .white)
                    .frame(width: w, height: h)
                    .mask(bgMask)
                    .styleAnchor(.background)

                // Aurora — three SVG blobs stacked + heavy-blurred,
                // then masked through the same silhouette so the
                // colour bleeds straight off the ticket edges.
                PrismBlobs(
                    scale: s,
                    tint1: style.tint1 ?? Color(hex: "EA72FF"),
                    tint2: style.tint2 ?? Color(hex: "FF007E"),
                    tint3: style.tint3 ?? Color(hex: "FFAA6C")
                )
                    .frame(width: w, height: h)
                    .mask(bgMask)

                // Blob anchor proxies for the StyleStep preview pills.
                // Live in the OUTER ZStack (NOT inside the masked
                // PrismBlobs) so each anchor reports a distinct rect
                // that the collision-resolver can place a separate
                // pill against without overlap.
                ZStack(alignment: .topLeading) {
                    // Glow — big magenta blob, visible centre roughly
                    // mid-left of the ticket.
                    blobAnchor(.tint1, cx: 230 * s, cy: 130 * s)
                    // Midtone — mid hot-pink, slightly right of glow.
                    blobAnchor(.tint2, cx: 320 * s, cy: 160 * s)
                    // Highlight — small peach, lower-right area.
                    blobAnchor(.tint3, cx: 410 * s, cy: 195 * s)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)

                // All overlays clipped to the same notched shape.
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .frame(width: w, height: h)

                    headerRow(scale: s)
                        .frame(width: w)

                    routeRow(scale: s)
                        .frame(width: w, height: 131 * s)
                        .offset(y: 58 * s)

                    footerBar(scale: s)
                        .frame(width: w, height: 49 * s)
                        .offset(y: 211 * s)
                }
                .mask(bgMask)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 32 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Header

    /// Header text uses `style.textPrimary` (default black) directly
    /// for primary lines, and at 55% for the supporting lines per the
    /// Figma spec (ticket number + "Boarding pass" eyebrow).
    private func headerRow(scale s: CGFloat) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4 * s) {
                Text(ticket.airline.uppercased())
                    .font(.system(size: 8 * s, weight: .bold))
                    .tracking(1.5 * s)
                    .foregroundStyle(style.textPrimary)

                Text(ticket.ticketNumber)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(0.5 * s)
                    .foregroundStyle(style.textPrimary.opacity(0.55))
            }

            Spacer(minLength: 0)

            madeWithBadge(scale: s)
                .padding(.top, 1 * s)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4 * s) {
                Text(ticket.date)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(0.5 * s)
                    .foregroundStyle(style.textPrimary)

                Text(verbatim: "Boarding pass")
                    .textCase(.uppercase)
                    .font(.system(size: 8 * s, weight: .bold))
                    .tracking(1.5 * s)
                    .foregroundStyle(style.textPrimary.opacity(0.55))
            }
        }
        .padding(.horizontal, 24 * s)
        .padding(.vertical, 16 * s)
    }

    // MARK: - Route

    private func routeRow(scale s: CGFloat) -> some View {
        HStack(spacing: 16 * s) {
            airportBlock(
                code: ticket.origin,
                name: ticket.originName,
                align: .trailing,
                scale: s
            )

            Text(verbatim: "→")
                .font(.system(size: 16 * s, weight: .regular))
                .foregroundStyle(style.textPrimary.opacity(0.45))

            airportBlock(
                code: ticket.destination,
                name: ticket.destinationName,
                align: .leading,
                scale: s
            )
        }
        .padding(.horizontal, 28 * s)
    }

    /// Airport name (small uppercase) renders at 45% of textPrimary
    /// per the Figma spec; the giant code stays at 82% (matches the
    /// existing optical balance against the bright aurora bleed).
    private func airportBlock(
        code: String,
        name: String,
        align: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: align, spacing: 0) {
            // Anchor only the destination block — single .textPrimary
            // anchor is enough for the preview pill, and it reads
            // cleanly on the right-hand side of the ticket.
            Group {
                if align == .leading {
                    Text(code)
                        .styleAnchor(.textPrimary)
                } else {
                    Text(code)
                }
            }
                .font(.custom("Georgia-Bold", size: 80 * s))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
                .fixedSize()

            Text(name.uppercased())
                .font(.system(size: 8 * s, weight: .bold))
                .tracking(1.76 * s)
                .foregroundStyle(style.textPrimary.opacity(0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: 175 * s, alignment: align == .leading ? .leading : .trailing)
    }

    // MARK: - Footer

    /// Detail bar uses `style.footerFill` for the strip background
    /// and `style.textSecondary` for the value text. Labels render at
    /// 30% of textSecondary; cell separators carry `style.divider`
    /// (textSecondary @ 7%).
    private func footerBar(scale s: CGFloat) -> some View {
        HStack(spacing: 0) {
            detailCell(label: "Gate",     value: ticket.gate,          showDivider: false, scale: s)
            detailCell(label: "Seat",     value: ticket.seat,          showDivider: true,  scale: s)
            detailCell(label: "Boards",   value: ticket.boardingTime,  showDivider: true,  scale: s)
            detailCell(label: "Departs",  value: ticket.departureTime, showDivider: true,  scale: s)
            detailCell(label: "Terminal", value: ticket.terminal,      showDivider: true,  scale: s)
        }
        .padding(.horizontal, 16 * s)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(style.footerFill)
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
                    .fill(style.divider)
                    .frame(width: 1)
                    .frame(height: 27 * s)
            }

            VStack(spacing: 3 * s) {
                Text(label).textCase(.uppercase)
                    .font(.system(size: 6 * s, weight: .regular))
                    .tracking(1.32 * s)
                    .foregroundStyle(style.textSecondary.opacity(0.3))

                Text(value)
                    .font(.system(size: 14 * s, weight: .bold))
                    .foregroundStyle(style.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 27 * s)
        }
    }

    @ViewBuilder
    private func madeWithBadge(scale s: CGFloat) -> some View {
        if showsLumoriaWatermark {
            MadeWithLumoria(style: .black, version: .small, scale: s)
        }
    }

    /// Invisible 16×16 anchor at a blob's APPARENT visible centre.
    /// Small rect → `rect.midX/midY` lands exactly at (cx, cy), so
    /// the StyleStep pill's leader points at the chosen spot.
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

// MARK: - Preview

#Preview {
    PrismTicketView(ticket: PrismTicket(
        airline: "Airline",
        ticketNumber: "Ticket number",
        date: "16 Aug 2026",
        origin: "SIN",
        originName: "Singapore Changi",
        destination: "HND",
        destinationName: "Tokyo Haneda",
        gate: "C34",
        seat: "11A",
        boardingTime: "08:40",
        departureTime: "09:10",
        terminal: "T3"
    ))
    .padding(24)
    .background(Color.Background.default)
}
