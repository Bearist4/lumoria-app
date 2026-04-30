//
//  GridTicketView.swift
//  Lumoria App
//
//  Horizontal public-transport ticket — "Grid" style. A 455×260
//  cream "graph paper" card with the line short-code centred in a
//  large soft halo of the line colour, the line's full name in a
//  small label directly under it, a horizontal {From} → {Destination}
//  row across the lower middle, the operator's name top-left, a
//  "Made with" pill top-right, and a meta row (Ticket / Date / Zone /
//  Fare) tucked above an 8pt strip of the line colour at the bottom
//  edge.
//
//  Layout proportions follow the Figma 455×260 design space; every
//  piece scales by `s = w / 455` so the rendering tracks its
//  parent.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=280-2616
//

import SwiftUI

struct GridTicketView: View {
    let ticket: UndergroundTicket

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .topLeading) {
                background

                // Soft line-colour halo behind the bullet (142×142 in
                // the design space, blurred so it fades into the
                // paper).
                Circle()
                    .fill(lineAccent.opacity(1))
                    .frame(width: 142 * s, height: 142 * s)
                    .blur(radius: 28 * s)
                    .padding(.leading, 157 * s)
                    .padding(.top, -5 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Big short-code over the line's full name. Wrapped
                // in a VStack so a long `lineName` can wrap to a
                // second line and shrink without exceeding the
                // halo's text area; the short-code rides up with the
                // group when the name grows.
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
                .position(x: 228 * s, y: 66 * s)

                // Origin → destination row across the lower middle,
                // straight horizontal layout per the updated figma.
                HStack(spacing: 24 * s) {
                    Text(ticket.originStation)
                    Text("→")
                    Text(ticket.destinationStation)
                }
                .font(.system(size: 15 * s, weight: .bold, design: .rounded))
                .tracking(-0.43 * s)
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: 380 * s)
                .position(x: 228 * s, y: 168 * s)

                // Operator label — small uppercase tracked across
                // the top-left corner.
                Text(ticket.companyName)
                    .font(.system(size: 9 * s, weight: .medium))
                    .tracking(1.35 * s)
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .padding(.leading, 16 * s)
                    .padding(.top, 16 * s)
                    .frame(
                        maxWidth: 200 * s, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Made-with pill, top-right.
                if showsLumoriaWatermark {
                    MadeWithLumoria(style: .black, version: .small, scale: s)
                        .padding(.trailing, 16 * s)
                        .padding(.top, 16 * s)
                        .frame(
                            maxWidth: .infinity, maxHeight: .infinity,
                            alignment: .topTrailing
                        )
                }

                // Meta row + line-colour strip at the bottom.
                bottomBar(scale: s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: w, height: h)
            .mask { background }
            .clipShape(RoundedRectangle(cornerRadius: 32 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Pieces

    /// Graph-paper background — horizontal variant. The user drops the
    /// asset into `tickets/grid-bg.imageset`; when the slot is empty
    /// we fall back to a flat cream tint so the ticket still renders.
    @ViewBuilder
    private var background: some View {
        if let _ = UIImage(named: "grid-bg") {
            Image("grid-bg")
                .resizable()
                .scaledToFill()
        } else {
            Color(red: 0.98, green: 0.96, blue: 0.92) // soft cream
        }
    }

    private func bottomBar(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            metaRow(scale: s)
                .padding(.horizontal, 16 * s)
                .padding(.top, 8 * s)
                .padding(.bottom, 16 * s)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 0.5)
                }

            // Line colour strip — the brand band along the bottom.
            Rectangle()
                .fill(lineAccent)
                .frame(height: 8 * s)
        }
    }

    private func metaRow(scale s: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 50 * s) {
            metaCell(label: "TICKET",   value: ticket.ticketNumber, scale: s)
                .frame(maxWidth: .infinity, alignment: .leading)
            metaCell(label: "DATE",     value: ticket.date,         scale: s)
            metaCell(label: "ZONE",     value: ticket.zones,        scale: s)
            metaCell(label: "FARE",     value: ticket.fare,         scale: s)
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

// MARK: - Preview

#Preview("Grid · Tokyo Ginza") {
    GridTicketView(
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

#Preview("Grid · London Circle") {
    GridTicketView(
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
