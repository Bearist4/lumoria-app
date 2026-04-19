//
//  TerminalTicketVerticalView.swift
//  Lumoria App
//
//  Vertical boarding-pass card for the "Terminal" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=4-869
//

import SwiftUI

struct TerminalTicketVerticalView: View {
    let ticket: TerminalTicket

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack(alignment: .topLeading) {
                // Ticket shape (rotated -90° ccw from the horizontal asset).
                rotatedLayer(name: "terminal-bg", w: w, h: h)

                // Gradient pre-composed for the vertical orientation.
                Image("terminal-gradient-vertical")
                    .resizable()
                    .frame(width: w, height: h)

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
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Rotated background layer helper

    private func rotatedLayer(name: String, w: CGFloat, h: CGFloat) -> some View {
        Image(name)
            .resizable()
            .frame(width: h, height: w)
            .rotationEffect(.degrees(-90))
            .frame(width: w, height: h)
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
            Text(label.uppercased())
                .font(.system(size: 4.59 * s, weight: .medium))
                .tracking(1 * s)
                .foregroundStyle(.white)

            Text(value)
                .font(.system(size: 9.18 * s, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            if showDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
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
                scale: s
            )

            Spacer(minLength: 0)

            airportBlock(
                code: ticket.destination,
                name: ticket.destinationName,
                location: ticket.destinationLocation,
                scale: s
            )
        }
        .padding(.horizontal, 24 * s)
    }

    private func airportBlock(
        code: String,
        name: String,
        location: String,
        scale s: CGFloat
    ) -> some View {
        VStack(spacing: 4 * s) {
            Text(code)
                .font(.custom("Doto-Black", size: 64 * s))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(name)
                .font(.system(size: 8 * s, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(location.uppercased())
                .font(.system(size: 6 * s, weight: .regular))
                .tracking(0.5 * s)
                .foregroundStyle(Color.white.opacity(0.4))
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
                    .foregroundStyle(Color.white.opacity(0.55))

                Text(ticket.ticketNumber)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(0.5 * s)
                    .foregroundStyle(.white)
            }

            Spacer()

            Text(ticket.cabinClass.uppercased())
                .font(.system(size: 6 * s, weight: .bold))
                .tracking(0.64 * s)
                .foregroundStyle(.white)
                .padding(.horizontal, 8 * s)
                .padding(.vertical, 4 * s)
                .background(
                    RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
                        .fill(Color.white.opacity(0.35))
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
                    .foregroundStyle(.black.opacity(0.9))

                Text(ticket.fullDate)
                    .font(.system(size: 10 * s, weight: .bold))
                    .foregroundStyle(.black.opacity(0.4))

                Text(ticket.cabinClass.uppercased())
                    .font(.system(size: 6 * s, weight: .bold))
                    .tracking(2 * s)
                    .foregroundStyle(.black.opacity(0.35))
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
