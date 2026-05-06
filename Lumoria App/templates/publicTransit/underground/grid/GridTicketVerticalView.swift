//
//  GridTicketVerticalView.swift
//  Lumoria App
//
//  Vertical (260×455) variant of the Grid public-transport ticket.
//  Same elements as the horizontal layout — line short-code halo
//  near the top with the line's full name beneath, an origin /
//  arrow / destination stack across the lower middle — with the
//  line-colour strip running full-width at the bottom (masked by
//  the background silhouette) and the meta row laid out as a 2×2
//  grid (Ticket / Date above Zone / Fare).
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=280-2720
//

import SwiftUI

struct GridTicketVerticalView: View {
    let ticket: UndergroundTicket

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack(alignment: .topLeading) {
                background

                // Soft halo — same 142×142 as horizontal, anchored
                // a touch lower because the bullet sits near the
                // upper third of the vertical card.
                Circle()
                    .fill(lineAccent.opacity(1))
                    .frame(width: 142 * s, height: 142 * s)
                    .blur(radius: 28 * s)
                    .padding(.leading, 59 * s)
                    .padding(.top, 78 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Short-code + line name as a single group inside
                // the halo so a long `lineName` can wrap to a second
                // line and shrink rather than truncate; the
                // short-code shifts up slightly when the name grows.
                VStack(spacing: 4 * s) {
                    Text(ticket.lineShortName)
                        .font(.system(size: 40 * s, weight: .bold, design: .rounded))
                        .tracking(-0.43 * s)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(ticket.lineName)
                        .font(.system(size: 12 * s, weight: .semibold, design: .rounded))
                        .tracking(-0.2 * s)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.black)
                .frame(width: 200 * s)
                .position(x: 130 * s, y: 149 * s)

                // Origin / arrow / destination stack across the
                // lower middle. Stacks vertically because the
                // 260pt card width can't fit two long station
                // names on a single horizontal line.
                VStack(alignment: .leading, spacing: 4 * s) {
                    Text(ticket.originStation)
                    Text("↓")
                    Text(ticket.destinationStation)
                }
                .font(.system(size: 17 * s, weight: .bold, design: .rounded))
                .tracking(-0.43 * s)
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.leading, 16 * s)
                // 16pt above the bottom meta-grid block (~110pt
                // tall in design coords: 12pt top + 58pt cells +
                // 32pt bottom + 8pt line strip).
                .padding(.bottom, 126 * s)
                .frame(
                    maxWidth: .infinity, maxHeight: .infinity,
                    alignment: .bottomLeading
                )

                // Operator label — top-left, 40pt from the top edge.
                Text(ticket.companyName)
                    .font(.system(size: 9 * s, weight: .medium))
                    .tracking(1.35 * s)
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .padding(.leading, 16 * s)
                    .padding(.top, 40 * s)
                    .frame(
                        maxWidth: 150 * s, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Made-with pill — rotated 90° CW so it reads
                // top-to-bottom along the right edge. Pivot around
                // its top-left corner, then offset so that pivot
                // sits 16pt from the top of the card and 16pt from
                // the right edge — i.e. the pill's original LEFT
                // edge ends up 16pt below the card top, and its
                // original TOP edge ends up 16pt left of the right
                // edge (matching the figma).
                if showsLumoriaWatermark {
                    MadeWithLumoria(style: .black, version: .small, scale: s)
                        .fixedSize()
                        .rotationEffect(.degrees(90), anchor: .topLeading)
                        .offset(x: w - 16 * s, y: 16 * s)
                        .frame(
                            maxWidth: .infinity, maxHeight: .infinity,
                            alignment: .topLeading
                        )
                }

                bottomGrid(scale: s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: w, height: h)
            .mask { background }
            .clipShape(RoundedRectangle(cornerRadius: 32 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Pieces

    @ViewBuilder
    private var background: some View {
        if let _ = UIImage(named: "grid-bg-vertical") {
            Image("grid-bg-vertical")
                .resizable()
                .scaledToFill()
        } else {
            Color(red: 0.98, green: 0.96, blue: 0.92)
        }
    }

    private func bottomGrid(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            // 2×2 meta grid — Ticket / Boarding above, Zone / Fare
            // below. Mirrors the Figma `grid-cols-2 grid-rows-2`.
            VStack(spacing: 16 * s) {
                HStack(alignment: .top, spacing: 16 * s) {
                    metaCell(label: "Ticket",   value: ticket.ticketNumber, scale: s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metaCell(label: "Date",     value: ticket.date,         scale: s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(alignment: .top, spacing: 16 * s) {
                    metaCell(label: "Zone", value: ticket.zones, scale: s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metaCell(label: "Fare", value: ticket.fare,  scale: s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

            }
            .padding(.horizontal, 16 * s)
            .padding(.top, 12 * s)
            .padding(.bottom, 32 * s)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 0.5)
            }

            // Full-width line-colour strip at the very bottom of
            // the card. The bottom edge of the background image is
            // used as a mask so any silhouette features in the
            // ticket asset (e.g. a notch or scalloped top) cut into
            // the strip naturally.
            Rectangle()
                .fill(lineAccent)
                .frame(height: 8 * s)
        }
    }

    private func metaCell(label: String, value: String, scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 8 * s, weight: .medium))
                .tracking(1.76 * s)
                .foregroundStyle(.black.opacity(0.3))
            Text(value)
                .font(.system(size: 13 * s, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    // MARK: - Derived

    private var lineAccent: Color {
        Color(hex: ticket.lineColor)
    }

}

#Preview("Grid Vertical · Tokyo Ginza") {
    GridTicketVerticalView(
        ticket: UndergroundTicket(
            lineShortName: "G",
            lineName: "Ginza Line",
            companyName: "Tokyo Metro",
            lineColor: "#FF9500",
            originStation: "Shibuya",
            destinationStation: "Asakusa",
            stopsCount: 18,
            date: "08:42",
            ticketNumber: "K7Q3X8M2WL",
            zones: "All zones",
            fare: "¥210",
            mode: 1
        )
    )
    .padding(24)
    .background(Color.Background.elevated)
}

#Preview("Grid Vertical · London Circle") {
    GridTicketVerticalView(
        ticket: UndergroundTicket(
            lineShortName: "CIR",
            lineName: "Circle line",
            companyName: "London",
            lineColor: "#FFD300",
            originStation: "Paddington",
            destinationStation: "Tower Hill",
            stopsCount: 12,
            date: "08:42",
            ticketNumber: "K7Q3X8M2WL",
            zones: "1–2",
            fare: "1.50€",
            mode: 1
        )
    )
    .padding(24)
    .background(Color.Background.elevated)
}
