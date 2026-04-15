//
//  StudioTicketVerticalView.swift
//  Lumoria App
//
//  Vertical boarding-pass card for the "Studio" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=1-1557
//

import SwiftUI

struct StudioTicketVerticalView: View {
    let ticket: StudioTicket

    private let aspectRatio: CGFloat = 260 / 455
    private let cornerRadius: CGFloat = 32

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack(alignment: .bottom) {
                // Rotated ticket shape (original is 455x260, rotated 90° cw → 260x455).
                Image("studio-bg")
                    .resizable()
                    .frame(width: h, height: w)
                    .rotationEffect(.degrees(90))
                    .frame(width: w, height: h)

                // Main content column.
                VStack(spacing: 0) {
                    headerSection(scale: s)

                    Spacer(minLength: 0)
                    divider
                    Spacer(minLength: 0)

                    routeSection(scale: s)
                        .frame(height: 231 * s)

                    Spacer(minLength: 0)
                    divider
                    Spacer(minLength: 0)

                    detailsSection(scale: s)
                        .frame(height: 32 * s)
                }
                .padding(.horizontal, 24 * s)
                .padding(.top, 36 * s)
                .padding(.bottom, 48 * s)
                .frame(width: w, height: h)

                // Black "Made with Lumoria" strip pinned to the bottom,
                // clipped to match the ticket's rounded bottom corners.
                madeWithStrip(scale: s)
                    .frame(width: w, height: 23 * s)
                    .clipShape(
                        UnevenRoundedRectangle(
                            bottomLeadingRadius: cornerRadius * s,
                            bottomTrailingRadius: cornerRadius * s
                        )
                    )
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Header

    private func headerSection(scale s: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 4 * s) {
            HStack {
                Text(ticket.airline.uppercased())
                    .font(.system(size: 8 * s, weight: .bold))
                    .foregroundStyle(.black.opacity(0.4))

                Spacer()

                Text(ticket.cabinClass)
                    .font(.system(size: 8 * s, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8 * s)
                    .padding(.vertical, 4 * s)
                    .background(
                        RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
                            .fill(Color(hex: "D94544"))
                    )
            }

            HStack {
                Text("\(ticket.flightNumber) · Boarding Pass")
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(0.44 * s)
                    .foregroundStyle(.black)
                    .lineLimit(1)

                Spacer()
            }
        }
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.07))
            .frame(height: 1)
    }

    // MARK: - Route

    private func routeSection(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            airportBlock(
                code: ticket.origin,
                name: ticket.originName,
                location: ticket.originLocation,
                scale: s
            )

            Spacer(minLength: 0)

            Image(systemName: "airplane")
                .font(.system(size: 16 * s, weight: .regular))
                .foregroundStyle(Color(hex: "D94544"))

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
                .font(.system(size: 48 * s, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(name)
                .font(.system(size: 9.41 * s, weight: .bold))
                .tracking(0.38 * s)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            Text(location.uppercased())
                .font(.system(size: 6.28 * s, weight: .regular))
                .tracking(0.75 * s)
                .foregroundStyle(.black.opacity(0.4))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
    }

    // MARK: - Footer details (Date / Gate / Seat / Departs)

    private func detailsSection(scale s: CGFloat) -> some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 16 * s) {
                detailCell(label: "Date",    value: ticket.date,          scale: s)
                pillDivider(scale: s)
                detailCell(label: "Gate",    value: ticket.gate,          scale: s)
                pillDivider(scale: s)
                detailCell(label: "Seat",    value: ticket.seat,          scale: s)
                pillDivider(scale: s)
                detailCell(label: "Departs", value: ticket.departureTime, scale: s)
            }

            Spacer()
        }
    }

    private func detailCell(label: String, value: String, scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: 5.49 * s, weight: .regular))
                .tracking(1.1 * s)
                .foregroundStyle(.black.opacity(0.4))

            Text(value)
                .font(.system(size: 10.98 * s, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(1)
        }
    }

    private func pillDivider(scale s: CGFloat) -> some View {
        Capsule()
            .fill(Color.black.opacity(0.1))
            .frame(width: 0.78 * s, height: 21.18 * s)
    }

    // MARK: - Bottom "Made with Lumoria" strip

    private func madeWithStrip(scale s: CGFloat) -> some View {
        HStack(alignment: .center) {
            Text("Made with")
                .font(.system(size: 6.78 * s, weight: .semibold))
                .tracking(-0.43 * s)
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 2.5 * s) {
                Image("brand/default/logomark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 6.34 * s, height: 6.34 * s)
                    .background(
                        RoundedRectangle(cornerRadius: 1.12 * s, style: .continuous)
                            .fill(Color(hex: "FFFCF0"))
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 1.12 * s, style: .continuous)
                    )

                Image("brand/default/full")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 2.8 * s)
                    .environment(\.colorScheme, .dark)
            }
        }
        .padding(.horizontal, 27.14 * s)
        .padding(.vertical, 4.79 * s)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - Preview

#Preview {
    StudioTicketVerticalView(ticket: StudioTicket(
        airline: "Airline",
        flightNumber: "FlightNumber",
        cabinClass: "Class",
        origin: "NRT",
        originName: "Narita International",
        originLocation: "Tokyo, Japan",
        destination: "JFK",
        destinationName: "John F. Kennedy",
        destinationLocation: "New York, United States",
        date: "8 Jun 2026",
        gate: "74",
        seat: "1K",
        departureTime: "11:05"
    ))
    .padding(24)
    .background(Color.Background.default)
}
