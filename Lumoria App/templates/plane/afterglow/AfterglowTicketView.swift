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
    var style: TicketStyleVariant = TicketTemplateKind.afterglow.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    // Ticket aspect ratio from Figma: 455 × 260
    private let aspectRatio: CGFloat = 455 / 260

    /// Convenience alias — the colour every secondary element on the
    /// ticket starts from. Each call site applies its own `.opacity(_:)`
    /// so the airline-icon's 60/50/40 step or a future hover state
    /// can layer cleanly without nested multiplications.
    private var secondary: Color { style.textPrimary }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let scale = w / 455

            ZStack {
                background(width: w, height: h, scale: scale)
                    .styleAnchor(.background)

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
                            .overlay(secondary.opacity(0.4))
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
                                .overlay(secondary.opacity(0.4))
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

    // MARK: - Background

    /// Renders Afterglow's signature dawn/dusk gradient. The two
    /// stops map directly onto the StyleStep's "Gradient start" /
    /// "Gradient end" controls:
    ///   • start (top-left)  ← `style.backgroundColor` override,
    ///                          falling back to Indigo/900 (#080055)
    ///   • end (bottom-right) ← `style.accent` (always set on the
    ///                          variant; default Blue/900 #001B2C)
    /// Hex literal default — NOT a palette token — so the gradient
    /// looks identical in light and dark mode. Tickets are fixed-look
    /// designs and must not auto-flip.
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

    // MARK: - Airline tag

    private func airlineTag(scale: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 8 * scale) {
            airlineIcon(scale: scale)
                

            VStack(alignment: .leading, spacing: 0) {
                Text(ticket.airline.uppercased())
                    .font(.system(size: 8 * scale, weight: .bold))
                    .tracking(0)
                    .foregroundStyle(secondary.opacity(0.4))

                Text(ticket.flightNumber)
                    .font(.system(size: 12 * scale, weight: .bold))
                    .tracking(0.39 * scale)
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

    // MARK: - Made with Lumoria badge

    @ViewBuilder
    private func madeWithBadge(scale: CGFloat) -> some View {
        if showsLumoriaWatermark {
            MadeWithLumoria(style: .white, version: .small, scale: scale)
        }
    }

    // MARK: - Route row

    private func routeRow(scale: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            // Origin
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(ticket.origin)
                    .font(.system(size: 56 * scale, weight: .black))
                    .tracking(0.23 * scale)
                    .foregroundStyle(style.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .styleAnchor(.textPrimary)

                Text(ticket.originCity.uppercased())
                    .font(.system(size: 8 * scale, weight: .regular))
                    .tracking(0.96 * scale)
                    .foregroundStyle(secondary.opacity(0.4))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Flight path — drawn in code so every stroke + glyph
            // tracks `secondary` (40% of the user's text color).
            // Matches the vertical view's silhouette: dot — line —
            // plane — line — dot.
            flightPath(scale: scale)
                .frame(maxWidth: 70)

            // Destination
            VStack(alignment: .trailing, spacing: 4 * scale) {
                Text(ticket.destination)
                    .font(.system(size: 56 * scale, weight: .black))
                    .tracking(0.23 * scale)
                    .foregroundStyle(style.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(ticket.destinationCity.uppercased())
                    .font(.system(size: 8 * scale, weight: .regular))
                    .tracking(0.96 * scale)
                    .foregroundStyle(secondary.opacity(0.4))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Flight path

    private func flightPath(scale s: CGFloat) -> some View {
        HStack(spacing: 4 * s) {
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
            Text(label).textCase(.uppercase)
                .font(.system(size: 8 * scale, weight: .regular))
                .tracking(1.06 * scale)
                .foregroundStyle(secondary.opacity(0.4))

            Text(value)
                .font(.system(size: 10 * scale, weight: .bold))
                .foregroundStyle(style.textPrimary)
        }
        .frame(maxWidth: .infinity)
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
