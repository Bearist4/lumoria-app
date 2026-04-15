//
//  AfterglowTicketView.swift
//  Lumoria App
//
//  Horizontal boarding-pass card for the "Afterglow" ticket style.
//

import SwiftUI

// MARK: - Model

struct AfterglowTicket: Codable, Hashable {
    var airline: String
    var flightNumber: String
    var origin: String          // IATA code e.g. "CDG"
    var originCity: String      // e.g. "Paris Charles de Gaulle"
    var destination: String     // IATA code e.g. "LAX"
    var destinationCity: String // e.g. "Los Angeles"
    var date: String            // e.g. "3 May 2026"
    var gate: String            // e.g. "F32"
    var seat: String            // e.g. "1A"
    var boardingTime: String    // e.g. "09:40"
}

// MARK: - View

struct AfterglowTicketView: View {
    let ticket: AfterglowTicket

    // Ticket aspect ratio from Figma: 455 × 260
    private let aspectRatio: CGFloat = 455 / 260

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let scale = w / 455

            ZStack {
                // Background SVG (ticket shape + gradient)
                Image("afterglow-bg")
                    .resizable()
                    .frame(width: w, height: h)

                // Content layout
                VStack(spacing: 0) {
                    // — Top row —
                    HStack(alignment: .top) {
                        airlineTag(scale: scale)
                        Spacer()
                        madeWithBadge(scale: scale)
                    }
                    .padding(.bottom, 17 * scale)
                    .overlay(alignment: .bottom) {
                        Divider()
                            .overlay(Color.white.opacity(0.1))
                    }

                    Spacer()

                    // — Middle: route —
                    routeRow(scale: scale)

                    Spacer()

                    // — Bottom: details —
                    detailsRow(scale: scale)
                        .padding(.top, 17 * scale)
                        .overlay(alignment: .top) {
                            Divider()
                                .overlay(Color.white.opacity(0.1))
                        }
                }
                .padding(.horizontal, 24 * scale)
                .padding(.vertical, 16 * scale)
                .frame(width: w, height: h)
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Airline tag

    private func airlineTag(scale: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 8 * scale) {
            Image("afterglow-airline-icon")
                .resizable()
                .scaledToFit()
                .frame(width: 9.5 * scale)

            VStack(alignment: .leading, spacing: 0) {
                Text(ticket.airline.uppercased())
                    .font(.system(size: 8 * scale, weight: .bold))
                    .tracking(0)
                    .foregroundStyle(Color.white.opacity(0.4))

                Text(ticket.flightNumber)
                    .font(.system(size: 12 * scale, weight: .bold))
                    .tracking(0.39 * scale)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Made with Lumoria badge

    private func madeWithBadge(scale: CGFloat) -> some View {
        HStack(spacing: 3.5 * scale) {
            Text("Made with")
                .font(.system(size: 7.5 * scale, weight: .semibold))
                .tracking(-0.43 * scale)
                .foregroundStyle(.black)

            HStack(spacing: 2.5 * scale) {
                Image("logomark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 7 * scale, height: 7 * scale)

                Text("Lumoria")
                    .font(.system(size: 7.5 * scale, weight: .semibold))
                    .tracking(-0.43 * scale)
                    .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, 5 * scale)
        .padding(.vertical, 5 * scale)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 5 * scale))
    }

    // MARK: - Route row

    private func routeRow(scale: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Origin
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(ticket.origin)
                    .font(.system(size: 56 * scale, weight: .black))
                    .tracking(0.23 * scale)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(ticket.originCity.uppercased())
                    .font(.system(size: 6.8 * scale, weight: .regular))
                    .tracking(0.96 * scale)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Flight path
            HStack(spacing: 4.5 * scale) {
                Image("afterglow-flight-path")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48 * scale)

                Text("✈")
                    .font(.system(size: 10.6 * scale))
                    .foregroundStyle(Color.white.opacity(0.4))

                Image("afterglow-flight-path")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48 * scale)
            }
            .frame(maxWidth: .infinity)

            // Destination
            VStack(alignment: .trailing, spacing: 4 * scale) {
                Text(ticket.destination)
                    .font(.system(size: 56 * scale, weight: .black))
                    .tracking(0.23 * scale)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(ticket.destinationCity.uppercased())
                    .font(.system(size: 6.8 * scale, weight: .regular))
                    .tracking(0.96 * scale)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Details row

    private func detailsRow(scale: CGFloat) -> some View {
        HStack(spacing: 0) {
            detailCell(label: "Date", value: ticket.date, scale: scale, showDivider: false)
            detailCell(label: "Gate", value: ticket.gate, scale: scale, showDivider: true)
            detailCell(label: "Seat", value: ticket.seat, scale: scale, showDivider: true)
            detailCell(label: "Boards", value: ticket.boardingTime, scale: scale, showDivider: true)
        }
    }

    private func detailCell(label: String, value: String, scale: CGFloat, showDivider: Bool) -> some View {
        VStack(spacing: 4 * scale) {
            Text(label.uppercased())
                .font(.system(size: 8 * scale, weight: .regular))
                .tracking(1.06 * scale)
                .foregroundStyle(Color.white.opacity(0.4))

            Text(value)
                .font(.system(size: 10 * scale, weight: .bold))
                .foregroundStyle(.white)
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
    AfterglowTicketView(ticket: AfterglowTicket(
        airline: "Airline",
        flightNumber: "AG 421",
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
}
