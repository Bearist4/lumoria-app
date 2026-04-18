//
//  HeritageTicketVerticalView.swift
//  Lumoria App
//
//  Vertical boarding-pass card for the "Heritage" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=1-2063
//

import SwiftUI

struct HeritageTicketVerticalView: View {
    let ticket: HeritageTicket

    @Environment(\.brandSlug) private var brandSlug

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack(alignment: .topLeading) {
                Image("heritage-bg-vertical")
                    .resizable()
                    .frame(width: w, height: h)

                headerRow(scale: s)
                    .frame(width: w)
                    .offset(x: 0, y: 0)

                routeStack(scale: s)
                    .frame(width: w)
                    .offset(x: 0, y: 75 * s)

                detailsRow(scale: s)
                    .frame(width: w)
                    .offset(x: 0, y: 319 * s)

                footerRow(scale: s)
                    .frame(width: w)
                    .offset(x: 0, y: 381 * s)
            }
            .frame(width: w, height: h)
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
                    .foregroundStyle(Color(hex: "3E9FDC"))

                Text(ticket.ticketNumber)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(0.5 * s)
                    .foregroundStyle(Color(hex: "00527A"))
            }

            Spacer(minLength: 0)

            Text(ticket.cabinClass.uppercased())
                .font(.system(size: 6 * s, weight: .bold))
                .tracking(0.64 * s)
                .foregroundStyle(.white)
                .padding(.horizontal, 8 * s)
                .padding(.vertical, 4 * s)
                .background(
                    RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
                        .fill(Color(hex: "1A88C5"))
                )
        }
        .padding(16 * s)
    }

    // MARK: - Route stack

    private func routeStack(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8 * s) {
            airportBlock(
                code: ticket.origin,
                name: ticket.originName,
                location: ticket.originLocation,
                codeColor: Color(hex: "1A88C5"),
                scale: s
            )

            HStack(spacing: 8 * s) {
                Text(verbatim: "↓")
                    .font(.custom("Georgia", size: 12.235 * s))
                    .foregroundStyle(.black)

                Text(ticket.flightDuration.uppercased())
                    .font(.system(size: 5.35 * s, weight: .bold))
                    .tracking(1.18 * s)
                    .foregroundStyle(.black)
            }

            airportBlock(
                code: ticket.destination,
                name: ticket.destinationName,
                location: ticket.destinationLocation,
                codeColor: Color(hex: "00527A"),
                scale: s
            )
        }
        .padding(.horizontal, 16 * s)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func airportBlock(
        code: String,
        name: String,
        location: String,
        codeColor: Color,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4 * s) {
            Text(code)
                .font(.custom("Georgia-Bold", size: 64 * s))
                .foregroundStyle(codeColor)
                .blendMode(.multiply)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(name)
                .font(.system(size: 8 * s, weight: .bold))
                .foregroundStyle(.black)
                .lineLimit(1)

            Text(location.uppercased())
                .font(.system(size: 6 * s, weight: .regular))
                .tracking(0.5 * s)
                .foregroundStyle(.black.opacity(0.4))
                .lineLimit(1)
        }
    }

    // MARK: - Details 5-cell row

    private func detailsRow(scale s: CGFloat) -> some View {
        HStack(spacing: 0) {
            detailCell(label: "Gate",    value: ticket.gate,          showDivider: false, scale: s)
            detailCell(label: "Seat",    value: ticket.seat,          showDivider: true,  scale: s)
            detailCell(label: "Boards",  value: ticket.boardingTime,  showDivider: true,  scale: s)
            detailCell(label: "Departs", value: ticket.departureTime, showDivider: true,  scale: s)
            detailCell(label: "Date",    value: ticket.date,          showDivider: true,  scale: s)
        }
        .padding(16 * s)
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
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 0.5)
            }

            VStack(spacing: 4 * s) {
                Text(label.uppercased())
                    .font(.system(size: 4.59 * s, weight: .medium))
                    .tracking(1.0 * s)
                    .foregroundStyle(Color(hex: "0070A7"))

                Text(value)
                    .font(.system(size: 9.18 * s, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 29.82 * s)
    }

    // MARK: - Footer

    private func footerRow(scale s: CGFloat) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4 * s) {
                Text("\(ticket.origin) → \(ticket.destination)")
                    .font(.system(size: 8 * s, weight: .bold))
                    .foregroundStyle(.black.opacity(0.6))

                Text(ticket.fullDate)
                    .font(.system(size: 10 * s, weight: .bold))
                    .foregroundStyle(.black.opacity(0.4))

                Text(ticket.cabinDetail.uppercased())
                    .font(.system(size: 6 * s, weight: .bold))
                    .tracking(2 * s)
                    .foregroundStyle(.black.opacity(0.35))
            }

            Spacer(minLength: 0)

            madeWithBadge(scale: s)
        }
        .padding(.horizontal, 16 * s)
        .padding(.vertical, 12 * s)
    }

    private func madeWithBadge(scale s: CGFloat) -> some View {
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
                        RoundedRectangle(cornerRadius: 1.24 * s, style: .continuous)
                            .fill(Color(hex: "FFFCF0"))
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 1.24 * s, style: .continuous)
                    )

                Image("brand/\(brandSlug)/full")
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
}

// MARK: - Preview

#Preview {
    HeritageTicketVerticalView(ticket: HeritageTicket(
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
