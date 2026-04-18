//
//  TerminalTicketView.swift
//  Lumoria App
//
//  Horizontal boarding-pass card for the "Terminal" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=4-724
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

    @Environment(\.brandSlug) private var brandSlug

    // Ticket aspect ratio from Figma: 455 × 260
    private let aspectRatio: CGFloat = 455 / 260

    // Perforation column width (left stub)
    private let stubWidth: CGFloat = 74

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .topLeading) {
                // Solid ticket shape + perforation dots.
                Image("terminal-bg")
                    .resizable()
                    .frame(width: w, height: h)

                // Gradient nebula masked to the ticket shape.
                Image("terminal-gradient")
                    .resizable()
                    .frame(width: w, height: h)

                // Left rotated stub column.
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
                    .foregroundStyle(Color.white.opacity(0.6))

                Text(ticket.fullDate)
                    .font(.system(size: 10 * s, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))

                Text(ticket.cabinClass.uppercased())
                    .font(.system(size: 6 * s, weight: .bold))
                    .tracking(2 * s)
                    .foregroundStyle(Color.white.opacity(0.35))
            }

            Spacer(minLength: 0)

            stubBadge(scale: s)
        }
        .padding(.horizontal, 16 * s)
        .padding(.vertical, 12 * s)
        .frame(width: 260 * s, height: 74 * s)
        .rotationEffect(.degrees(90))
    }

    private func stubBadge(scale s: CGFloat) -> some View {
        HStack(spacing: 3.5 * s) {
            Text("Made with")
                .font(.system(size: 7.48 * s, weight: .semibold))
                .tracking(-0.43 * s)
                .foregroundStyle(.black)

            HStack(spacing: 2.5 * s) {
                Image("brand/\(brandSlug)/logomark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 7 * s, height: 7 * s)
                    .background(
                        RoundedRectangle(cornerRadius: 1.236 * s, style: .continuous)
                            .fill(Color(hex: "FFFCF0"))
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 1.236 * s, style: .continuous)
                    )

                Image("brand/\(brandSlug)/full")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 3 * s)
                    .environment(\.colorScheme, .light)
            }
        }
        .padding(5.28 * s)
        .background(
            RoundedRectangle(cornerRadius: 5.28 * s, style: .continuous)
                .fill(.white)
        )
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

    // MARK: - Route row

    private func routeRow(scale s: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            airportBlock(
                code: ticket.origin,
                name: ticket.originName,
                location: ticket.originLocation,
                alignment: .leading,
                scale: s
            )

            Spacer(minLength: 0)

            airportBlock(
                code: ticket.destination,
                name: ticket.destinationName,
                location: ticket.destinationLocation,
                alignment: .leading,
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
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: alignment, spacing: 4 * s) {
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
    }

    // MARK: - Bottom row

    private func bottomRow(scale s: CGFloat) -> some View {
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
