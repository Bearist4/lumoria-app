//
//  PrismTicketVerticalView.swift
//  Lumoria App
//
//  Vertical boarding-pass card for the "Prism" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=3-2509
//
//  Self-contained: blob shapes + composition view live in this file
//  so the horizontal Prism view stays untouched. Aurora positions
//  rebased for the 260×455 vertical canvas — large blob (0, 10),
//  middle blob (32, 10), small blob (45, −31). All other geometry
//  (viewBoxes, blur radii, internal rotation of the small ellipse)
//  matches the horizontal export exactly.
//

import SwiftUI

struct PrismTicketVerticalView: View {
    let ticket: PrismTicket
    var style: TicketStyleVariant = TicketTemplateKind.prism.defaultStyle

    @Environment(\.ticketFillsNotchCutouts) private var fillsNotchCutouts
    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            let bgMask = Image("prism-bg-vertical")
                .resizable()
                .frame(width: w, height: h)

            ZStack(alignment: .top) {
                // Paper base.
                Rectangle()
                    .fill(style.backgroundColor ?? .white)
                    .frame(width: w, height: h)
                    .mask(bgMask)
                    .styleAnchor(.background)

                // Aurora — three SVG blobs stacked + heavy-blurred,
                // masked through the same notched silhouette so the
                // colour bleeds off the ticket edges.
                PrismVerticalBlobs(
                    scale: s,
                    tint1: style.tint1 ?? Color(hex: "EA72FF"),
                    tint2: style.tint2 ?? Color(hex: "FF007E"),
                    tint3: style.tint3 ?? Color(hex: "FFAA6C")
                )
                .frame(width: w, height: h)
                .mask(bgMask)

                // Blob anchor proxies — small 16×16 rects placed at
                // each blob's APPARENT visible centre on the 260×455
                // vertical canvas. Living OUTSIDE the masked subtree
                // so the StyleStep proxy reads the offset positions
                // accurately and the collision-resolver places one
                // pill per blob without overlap.
                ZStack(alignment: .topLeading) {
                    blobAnchor(.tint1, cx: 130 * s, cy: 140 * s)
                    blobAnchor(.tint2, cx: 195 * s, cy: 200 * s)
                    blobAnchor(.tint3, cx: 200 * s, cy: 130 * s)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)

                // All overlays clipped to the same notched shape.
                ZStack(alignment: .top) {
                    Color.clear
                        .frame(width: w, height: h)

                    headerRow(scale: s)
                        .frame(width: w)

                    routeStack(scale: s)
                        .frame(width: w)
                        .offset(y: 80 * s)

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        footerBlock(scale: s)
                            .frame(width: w, height: 132 * s)
                    }
                }
                .mask(bgMask)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 32 * s, style: .continuous))
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
                    .foregroundStyle(style.textPrimary)

                Text(ticket.ticketNumber)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(0.5 * s)
                    .foregroundStyle(style.textPrimary.opacity(0.55))
            }

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
        .padding(.horizontal, 16 * s)
        .padding(.top, 36 * s)
        .padding(.bottom, 16 * s)
    }

    // MARK: - Route

    private func routeStack(scale s: CGFloat) -> some View {
        VStack(alignment: .center, spacing: 4 * s) {
            airportBlock(
                code: ticket.origin,
                name: ticket.originName,
                align: .leading,
                anchor: false,
                scale: s
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(verbatim: "↓")
                .font(.system(size: 16 * s, weight: .regular))
                .foregroundStyle(style.textPrimary.opacity(0.5))

            airportBlock(
                code: ticket.destination,
                name: ticket.destinationName,
                align: .trailing,
                anchor: true,
                scale: s
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.bottom, 12 * s)
    }

    private func airportBlock(
        code: String,
        name: String,
        align: HorizontalAlignment,
        anchor: Bool,
        scale s: CGFloat
    ) -> some View {
        let codeOverhang: CGFloat = align == .leading ? -13 * s : 0
        let codeOverhangTrailing: CGFloat = align == .trailing ? -12 * s : 0
        let nameInset: CGFloat = 8 * s

        return VStack(alignment: align, spacing: 0) {
            // Anchor only the destination block — single .textPrimary
            // anchor is enough for the preview pill.
            Group {
                if anchor {
                    Text(code).styleAnchor(.textPrimary)
                } else {
                    Text(code)
                }
            }
            .font(.custom("Georgia-Bold", size: 80 * s))
            .foregroundStyle(style.textPrimary.opacity(0.82))
            .lineLimit(1)
            .fixedSize()
            .padding(.leading, codeOverhang)
            .padding(.trailing, codeOverhangTrailing)

            Text(name.uppercased())
                .font(.system(size: 8 * s, weight: .bold))
                .tracking(1.76 * s)
                .foregroundStyle(style.textPrimary.opacity(0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.leading, align == .leading ? nameInset : 0)
                .padding(.trailing, align == .trailing ? nameInset : 0)
        }
    }

    // MARK: - Footer block

    private func footerBlock(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack {
                style.footerFill

                VStack(spacing: 12 * s) {
                    HStack(spacing: 8 * s) {
                        detailCell(label: "Gate",   value: ticket.gate,         align: .leading,  scale: s)
                        detailCell(label: "Seat",   value: ticket.seat,         align: .center,   scale: s)
                        detailCell(label: "Boards", value: ticket.boardingTime, align: .trailing, scale: s)
                    }

                    HStack(spacing: 8 * s) {
                        detailCell(label: "Departs",  value: ticket.departureTime, align: .leading,  scale: s)
                        detailCell(label: "Terminal", value: ticket.terminal,      align: .trailing, scale: s)
                    }
                }
                .padding(.horizontal, 16 * s)
                .padding(.vertical, 12 * s)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            madeWithStrip(scale: s)
                .frame(height: 40 * s)
        }
    }

    private func detailCell(
        label: String,
        value: String,
        align: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: align, spacing: 3 * s) {
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
        .frame(maxWidth: .infinity, alignment: alignment(for: align))
        .frame(height: 27 * s)
    }

    private func alignment(for h: HorizontalAlignment) -> Alignment {
        switch h {
        case .leading:  return .leading
        case .trailing: return .trailing
        default:        return .center
        }
    }

    // MARK: - Made with strip (bottom)

    @ViewBuilder
    private func madeWithStrip(scale s: CGFloat) -> some View {
        ZStack {
            Color.white
            if showsLumoriaWatermark {
                MadeWithLumoria(
                    style: .white,
                    version: .full,
                    scale: s,
                    fullWidth: true
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 40 * s)
    }

    /// Standardised blob anchor — same shape as the horizontal Prism
    /// helper. Small 16×16 rect at the chosen visible centre so the
    /// StyleStep pill's leader lands exactly at (cx, cy).
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

// MARK: - Aurora blobs (vertical-only)

/// Three Figma-exported blobs stacked + heavy-blurred for the
/// vertical Prism canvas. ViewBoxes and blur radii match the
/// horizontal export; only the (x, y) offsets differ — rebased for
/// the 260×455 vertical canvas. Render order: large magenta back →
/// mid hot-pink → small peach front.
private struct PrismVerticalBlobs: View {
    let scale: CGFloat
    let tint1: Color
    let tint2: Color
    let tint3: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Large blob — viewBox 409×260, position (0, 10).
            VerticalBigBlob()
                .fill(tint1)
                .frame(width: 409 * scale, height: 260 * scale)
                .blur(radius: 57.4 * scale)
                .offset(x: 0, y: 10 * scale)

            // Mid blob — viewBox 330×260, position (32, 10).
            VerticalMidBlob()
                .fill(tint2)
                .frame(width: 330 * scale, height: 260 * scale)
                .blur(radius: 38.3 * scale)
                .offset(x: 32 * scale, y: 10 * scale)

            // Small ellipse — viewBox 272×260, position (45, −31).
            // Internal SVG rotation 21.9106° around the ellipse
            // centre; outer rotation -20° matching horizontal.
            ZStack(alignment: .topLeading) {
                Ellipse()
                    .fill(tint3)
                    .frame(width: 213.002 * scale, height: 145.064 * scale)
                    .rotationEffect(.degrees(21.9106))
                    .offset(
                        x: (179.025 - 213.002 / 2) * scale,
                        y: (152.965 - 145.064 / 2) * scale
                    )
            }
            .frame(width: 272 * scale, height: 260 * scale, alignment: .topLeading)
            .rotationEffect(.degrees(-20))
            .blur(radius: 38.3 * scale)
            .offset(x: 45 * scale, y: -31 * scale)
        }
    }
}

/// Same path as the horizontal `PrismBigBlob`. ViewBox 409×260.
private struct VerticalBigBlob: Shape {
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

/// Same path as the horizontal `PrismMidBlob`. ViewBox 330×260.
private struct VerticalMidBlob: Shape {
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

// MARK: - Preview

#Preview {
    PrismTicketVerticalView(ticket: PrismTicket(
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
