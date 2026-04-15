//
//  AfterglowTicketVerticalView.swift
//  Lumoria App
//
//  Vertical boarding-pass card for the "Afterglow" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=4-426
//

import SwiftUI

struct AfterglowTicketVerticalView: View {
    let ticket: AfterglowTicket

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack {
                // Rotated horizontal bg fills the vertical canvas.
                Image("afterglow-bg")
                    .resizable()
                    .frame(width: h, height: w)
                    .rotationEffect(.degrees(90))
                    .frame(width: w, height: h)

                VStack(spacing: 0) {
                    topRow(scale: s)
                        .padding(.bottom, 17 * s)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 1)
                        }

                    Spacer(minLength: 0)

                    routeBlock(scale: s)

                    Spacer(minLength: 0)

                    detailsRow(scale: s)
                        .padding(.top, 17 * s)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 1)
                        }
                }
                .padding(16 * s)
                .frame(width: w, height: h)
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Top row

    private func topRow(scale s: CGFloat) -> some View {
        HStack(alignment: .top) {
            airlineTag(scale: s)
            Spacer()
            madeWithBadge(scale: s)
        }
    }

    private func airlineTag(scale s: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 8 * s) {
            Image("afterglow-airline-icon")
                .resizable()
                .scaledToFit()
                .frame(width: 9.5 * s)

            VStack(alignment: .leading, spacing: 0) {
                Text(ticket.airline.uppercased())
                    .font(.system(size: 8 * s, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))

                Text(ticket.flightNumber)
                    .font(.system(size: 12 * s, weight: .bold))
                    .tracking(0.39 * s)
                    .foregroundStyle(.white)
            }
        }
    }

    private func madeWithBadge(scale s: CGFloat) -> some View {
        HStack(spacing: 3.5 * s) {
            Text("Made with")
                .font(.system(size: 7.48 * s, weight: .semibold))
                .tracking(-0.43 * s)
                .foregroundStyle(.black)

            HStack(spacing: 2.5 * s) {
                Image("brand/default/logomark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 7 * s, height: 7 * s)
                    .background(
                        RoundedRectangle(cornerRadius: 1.24 * s, style: .continuous)
                            .fill(Color(hex: "FFFCF0"))
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 1.24 * s, style: .continuous)
                    )

                Image("brand/default/full")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 3 * s)
            }
        }
        .padding(5.28 * s)
        .background(
            RoundedRectangle(cornerRadius: 5.28 * s, style: .continuous)
                .fill(.white)
        )
    }

    // MARK: - Route block

    private func routeBlock(scale s: CGFloat) -> some View {
        VStack(spacing: 43.4 * s) {
            airportBlock(
                code: ticket.origin,
                city: ticket.originCity,
                scale: s
            )

            flightPath(scale: s)

            airportBlock(
                code: ticket.destination,
                city: ticket.destinationCity,
                scale: s
            )
        }
    }

    private func airportBlock(code: String, city: String, scale s: CGFloat) -> some View {
        VStack(spacing: 4 * s) {
            Text(code)
                .font(.system(size: 64 * s, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(city.uppercased())
                .font(.system(size: 6.83 * s, weight: .regular))
                .tracking(0.96 * s)
                .foregroundStyle(Color.white.opacity(0.5))
                .lineLimit(1)
        }
    }

    private func flightPath(scale s: CGFloat) -> some View {
        HStack(spacing: 4.55 * s) {
            Circle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 3.79 * s, height: 3.79 * s)

            Capsule()
                .fill(Color.white.opacity(0.4))
                .frame(height: 0.76 * s)

            Image(systemName: "airplane")
                .font(.system(size: 10.6 * s))
                .foregroundStyle(Color.white.opacity(0.4))

            Capsule()
                .fill(Color.white.opacity(0.4))
                .frame(height: 0.76 * s)

            Circle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 3.79 * s, height: 3.79 * s)
        }
        .frame(width: 123.18 * s)
    }

    // MARK: - Details row

    private func detailsRow(scale s: CGFloat) -> some View {
        HStack(spacing: 0) {
            detailCell(label: "Date",   value: ticket.date,         showDivider: false, scale: s)
            detailCell(label: "Gate",   value: ticket.gate,         showDivider: true,  scale: s)
            detailCell(label: "Seat",   value: ticket.seat,         showDivider: true,  scale: s)
            detailCell(label: "Boards", value: ticket.boardingTime, showDivider: true,  scale: s)
        }
    }

    private func detailCell(
        label: String,
        value: String,
        showDivider: Bool,
        scale s: CGFloat
    ) -> some View {
        VStack(spacing: 4 * s) {
            Text(label.uppercased())
                .font(.system(size: 8 * s, weight: .regular))
                .tracking(1.06 * s)
                .foregroundStyle(Color.white.opacity(0.4))

            Text(value)
                .font(.system(size: 10 * s, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            if showDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 1)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AfterglowTicketVerticalView(ticket: AfterglowTicket(
        airline: "Airline",
        flightNumber: "FlightNumber",
        origin: "CDG",
        originCity: "Paris Charles de Gaulle",
        destination: "LAX",
        destinationCity: "Los Angeles",
        date: "3 May 2026",
        gate: "F32",
        seat: "1A",
        boardingTime: "09:40"
    ))
    .padding(24)
    .background(Color.black)
}
