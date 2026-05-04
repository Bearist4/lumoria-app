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
    var style: TicketStyleVariant = TicketTemplateKind.afterglow.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    /// Convenience alias — the colour every secondary element on the
    /// ticket starts from. Each call site applies its own `.opacity(_:)`
    /// so the airline-icon's stepped opacities or a future hover state
    /// can layer cleanly without nested multiplications.
    private var secondary: Color { style.textPrimary }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack {
                background(width: w, height: h, scale: s)
                    .styleAnchor(.background)

                VStack(spacing: 0) {
                    topRow(scale: s)
                        .padding(.bottom, 17 * s)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(secondary.opacity(0.4))
                                .frame(height: 1)
                        }

                    Spacer(minLength: 0)

                    routeBlock(scale: s)

                    Spacer(minLength: 0)

                    detailsRow(scale: s)
                        .padding(.top, 17 * s)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(secondary.opacity(0.4))
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

    // MARK: - Background

    /// Vertical canvas — same two-stop gradient as the horizontal
    /// view. `style.backgroundColor` (default Indigo/900 #080055)
    /// drives the top-left start; `style.accent` (default Blue/900
    /// #001B2C) drives the bottom-right end. Hex literals so the
    /// look stays identical across appearance modes.
    @ViewBuilder
    private func background(width w: CGFloat, height h: CGFloat, scale: CGFloat) -> some View {
        let start = style.backgroundColor ?? Color(hex: "080055")
        LinearGradient(
            colors: [start, style.accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 32 * scale, style: .continuous))
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
            airlineIcon(scale: s)

            VStack(alignment: .leading, spacing: 0) {
                Text(ticket.airline.uppercased())
                    .font(.system(size: 8 * s, weight: .bold))
                    .foregroundStyle(secondary.opacity(0.4))

                Text(ticket.flightNumber)
                    .font(.system(size: 12 * s, weight: .bold))
                    .tracking(0.39 * s)
                    .foregroundStyle(style.textPrimary)
            }
        }
    }

    /// Three 2pt-wide vertical bars spaced 2pt apart. Built from the
    /// shared `secondary` tone (the same colour every other secondary
    /// element on this ticket uses), stepped 50% → 40% → 30% across
    /// the bars so the icon stays inside the secondary hierarchy.
    private func airlineIcon(scale s: CGFloat) -> some View {
        HStack(spacing: 2 * s) {
            Rectangle()
                .fill(secondary.opacity(0.6))
                .frame(width: 4 * s)
            Rectangle()
                .fill(secondary.opacity(0.5))
                .frame(width: 3 * s)
            Rectangle()
                .fill(secondary.opacity(0.4))
                .frame(width: 2 * s)
        }
        .frame(width: 10 * s, height: 25 * s)
    }

    @ViewBuilder
    private func madeWithBadge(scale s: CGFloat) -> some View {
        if showsLumoriaWatermark {
            MadeWithLumoria(style: .white, version: .small, scale: s)
        }
    }

    // MARK: - Route block

    private func routeBlock(scale s: CGFloat) -> some View {
        VStack(spacing: 43.4 * s) {
            airportBlock(
                code: ticket.origin,
                city: ticket.originCity,
                scale: s,
                isFirst: true
            )

            flightPath(scale: s)

            airportBlock(
                code: ticket.destination,
                city: ticket.destinationCity,
                scale: s,
                isFirst: false
            )
        }
    }

    private func airportBlock(code: String, city: String, scale s: CGFloat, isFirst: Bool) -> some View {
        VStack(spacing: 4 * s) {
            Group {
                if isFirst {
                    Text(code)
                        .styleAnchor(.textPrimary)
                } else {
                    Text(code)
                }
            }
            .font(.system(size: 64 * s, weight: .black))
            .foregroundStyle(style.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            Text(city.uppercased())
                .font(.system(size: 6.83 * s, weight: .regular))
                .tracking(0.96 * s)
                .foregroundStyle(secondary.opacity(0.4))
                .lineLimit(1)
        }
    }

    private func flightPath(scale s: CGFloat) -> some View {
        HStack(spacing: 4.55 * s) {
            Circle()
                .fill(secondary.opacity(0.4))
                .frame(width: 3.79 * s, height: 3.79 * s)

            Capsule()
                .fill(secondary.opacity(0.4))
                .frame(height: 0.76 * s)

            Image(systemName: "airplane")
                .font(.system(size: 10.6 * s))
                .foregroundStyle(secondary.opacity(0.4))

            Capsule()
                .fill(secondary.opacity(0.4))
                .frame(height: 0.76 * s)

            Circle()
                .fill(secondary.opacity(0.4))
                .frame(width: 3.79 * s, height: 3.79 * s)
        }
        .frame(width: 123.18 * s)
    }

    // MARK: - Details row

    private func detailsRow(scale s: CGFloat) -> some View {
        HStack(spacing: 0) {
            detailCell(label: "Date",   value: ticket.date,         showDivider: false, scale: s)
            // Gate + Seat values are short ("F32", "1A") — capping
            // their cell width at 45pt frees room for Date + Boards,
            // which carry longer strings ("3 May 2026" / "09:40")
            // and would otherwise share the row equally.
            detailCell(label: "Gate",   value: ticket.gate,         showDivider: true,  scale: s, maxWidth: 45 * s)
            detailCell(label: "Seat",   value: ticket.seat,         showDivider: true,  scale: s, maxWidth: 45 * s)
            detailCell(label: "Boards", value: ticket.boardingTime, showDivider: true,  scale: s)
        }
    }

    private func detailCell(
        label: String,
        value: String,
        showDivider: Bool,
        scale s: CGFloat,
        maxWidth: CGFloat? = nil
    ) -> some View {
        VStack(spacing: 4 * s) {
            Text(label.uppercased())
                .font(.system(size: 8 * s, weight: .regular))
                .tracking(1.06 * s)
                .foregroundStyle(secondary.opacity(0.4))

            Text(value)
                .font(.system(size: 10 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: maxWidth ?? .infinity)
        .overlay(alignment: .leading) {
            if showDivider {
                Rectangle()
                    .fill(secondary.opacity(0.4))
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
