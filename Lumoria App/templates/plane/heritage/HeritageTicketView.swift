//
//  HeritageTicketView.swift
//  Lumoria App
//
//  Horizontal boarding-pass card for the "Heritage" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=1-2221
//

import SwiftUI

// MARK: - Model

struct HeritageTicket: Codable, Hashable {
    var airline: String                 // "Airline"
    var ticketNumber: String            // "Ticket number · Aircraft"
    var cabinClass: String              // "Class"
    var cabinDetail: String             // "Business · The Pier"
    var origin: String                  // "HKG"
    var originName: String              // "Hong Kong International"
    var originLocation: String          // "Hong Kong"
    var destination: String             // "LHR"
    var destinationName: String         // "London Heathrow"
    var destinationLocation: String     // "London, United Kingdom"
    var flightDuration: String          // "9h 40m · Non-stop"
    var gate: String                    // "42"
    var seat: String                    // "11A"
    var boardingTime: String            // "22:10"
    var departureTime: String           // "22:55"
    var date: String                    // "4 Sep"
    var fullDate: String                // "4 Sep 2026"
}

// MARK: - View

struct HeritageTicketView: View {
    let ticket: HeritageTicket

    private let aspectRatio: CGFloat = 455 / 260
    private let stubWidth: CGFloat = 74

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .topLeading) {
                Image("heritage-bg")
                    .resizable()
                    .frame(width: w, height: h)

                stubColumn(scale: s)
                    .frame(width: stubWidth * s, height: h)

                VStack(spacing: 0) {
                    headerRow(scale: s)
                    Spacer(minLength: 0)
                    routeRow(scale: s)
                    Spacer(minLength: 0)
                    footerRow(scale: s)
                }
                .frame(width: (455 - stubWidth) * s, height: h)
                .offset(x: stubWidth * s, y: 0)
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Rotated stub column (left 74pt)

    private func stubColumn(scale s: CGFloat) -> some View {
        // Unrotated content block sized 260x74; rotated 90° clockwise fills 74x260.
        let cw: CGFloat = 260 * s
        let ch: CGFloat = stubWidth * s

        return ZStack {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4 * s) {
                    Text("\(ticket.origin) → \(ticket.destination)")
                        .font(.system(size: 8 * s, weight: .bold))
                        .foregroundStyle(.black.opacity(0.6))

                    Text(ticket.fullDate)
                        .font(.system(size: 10 * s, weight: .bold))
                        .foregroundStyle(.black.opacity(0.4))

                    Text(ticket.cabinClass.uppercased())
                        .font(.system(size: 6 * s, weight: .bold))
                        .tracking(2 * s)
                        .foregroundStyle(.black.opacity(0.35))
                }

                Spacer(minLength: 0)

                madeWithBadge(scale: s)
            }
            .padding(.horizontal, 16 * s)
            .padding(.vertical, 12 * s)
            .frame(width: cw, height: ch)
        }
        .frame(width: cw, height: ch)
        .rotationEffect(.degrees(-90))
        .frame(width: ch, height: cw)
    }

    // MARK: - Header row

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
        .padding(.horizontal, 24 * s)
        .padding(.vertical, 16 * s)
    }

    // MARK: - Route row

    private func routeRow(scale s: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            airportBlock(
                code: ticket.origin,
                name: ticket.originName,
                location: ticket.originLocation,
                codeColor: Color(hex: "1A88C5"),
                alignment: .leading,
                scale: s
            )

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                Text("→")
                    .font(.custom("Georgia", size: 12.235 * s))
                    .foregroundStyle(.black)

                Text(ticket.flightDuration.uppercased())
                    .font(.system(size: 5.35 * s, weight: .bold))
                    .tracking(1.18 * s)
                    .foregroundStyle(.black)
            }

            Spacer(minLength: 0)

            airportBlock(
                code: ticket.destination,
                name: ticket.destinationName,
                location: ticket.destinationLocation,
                codeColor: Color(hex: "00527A"),
                alignment: .trailing,
                scale: s
            )
        }
        .padding(.horizontal, 24 * s)
    }

    private func airportBlock(
        code: String,
        name: String,
        location: String,
        codeColor: Color,
        alignment: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        let textAlign: TextAlignment = (alignment == .leading) ? .leading : .trailing
        return VStack(alignment: alignment, spacing: 4 * s) {
            Text(code)
                .font(.custom("Georgia-Bold", size: 48 * s))
                .foregroundStyle(codeColor)
                .blendMode(.multiply)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(name)
                .font(.system(size: 8 * s, weight: .bold))
                .foregroundStyle(.black)
                .multilineTextAlignment(textAlign)
                .lineLimit(1)

            Text(location.uppercased())
                .font(.system(size: 6 * s, weight: .regular))
                .tracking(0.5 * s)
                .foregroundStyle(.black.opacity(0.4))
                .multilineTextAlignment(textAlign)
                .lineLimit(1)
        }
    }

    // MARK: - Footer 5-cell row

    private func footerRow(scale s: CGFloat) -> some View {
        HStack(spacing: 0) {
            detailCell(label: "Gate",    value: ticket.gate,          showDivider: false, scale: s)
            detailCell(label: "Seat",    value: ticket.seat,          showDivider: true,  scale: s)
            detailCell(label: "Boards",  value: ticket.boardingTime,  showDivider: true,  scale: s)
            detailCell(label: "Departs", value: ticket.departureTime, showDivider: true,  scale: s)
            detailCell(label: "Date",    value: ticket.date,          showDivider: true,  scale: s)
        }
        .padding(.horizontal, 24 * s)
        .padding(.vertical, 8 * s)
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

    // MARK: - Made with Lumoria badge

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
}

// MARK: - Preview

#Preview {
    HeritageTicketView(ticket: HeritageTicket(
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
