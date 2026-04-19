//
//  OrientTicketVerticalView.swift
//  Lumoria App
//
//  Vertical Orient-Express train ticket. Same palette and typography
//  as the horizontal variant, restacked for portrait.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=55-2469
//

import SwiftUI

struct OrientTicketVerticalView: View {
    let ticket: OrientTicket
    var style: TicketStyleVariant = TicketTemplateKind.orient.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack(alignment: .topLeading) {
                // Full-bleed artwork — contains navy field, gold
                // border, and the top tinted bar.
                if let base = style.backgroundAsset {
                    Image("\(base)-vertical")
                        .resizable()
                        .frame(width: w, height: h)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    citiesColumn(scale: s)
                        .padding(.horizontal, 24 * s)
                        .padding(.top, 72 * s)
                    Spacer(minLength: 0)

                    passengerRow(scale: s)
                        .padding(.horizontal, 20 * s)
                        .padding(.vertical, 12 * s)
                        .padding(.top, 8 * s)

                    detailsGrid(scale: s)
                        .padding(.horizontal, 12 * s)
                        .padding(.vertical, 12 * s)
                }
                // Reserves vertical space at the bottom for the half-
                // circle notch in the artwork plus the full-width
                // "Made with Lumoria" strip that's overlaid separately.
                // Content above stops before this zone so text never
                // falls into the notch.
                .padding(.bottom, 40 * s)
                .frame(width: w, height: h, alignment: .topLeading)

                // Bottom "Made with Lumoria" strip — spans full width
                // and is masked by the bottom of the background artwork
                // so it follows every cutout / rounded edge.
                if showsLumoriaWatermark {
                    madeWithStrip(scale: s, w: w, h: h)
            
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 24 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Cities (stacked, opposite alignment)

    private func citiesColumn(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16 * s) {
            cityBlock(
                label: "DEPARTS",
                city: ticket.originCity,
                station: ticket.originStation,
                alignment: .leading,
                scale: s
            )

            cityBlock(
                label: "ARRIVES",
                city: ticket.destinationCity,
                station: ticket.destinationStation,
                alignment: .trailing,
                scale: s
            )
        }
    }

    private func cityBlock(
        label: String,
        city: String,
        station: String,
        alignment: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(label)
                .font(.system(size: 8 * s, weight: .light))
                .tracking(2 * s)
                .foregroundStyle(style.textSecondary)

            Text(city)
                .font(.playfair(size: 32 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(station)
                .font(.playfair(size: 8 * s, italic: true))
                .foregroundStyle(style.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    // MARK: - Passenger row

    private func passengerRow(scale s: CGFloat) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Passenger")
                    .font(.system(size: 6.5 * s, weight: .light))
                    .tracking(1.3 * s)
                    .textCase(.uppercase)
                    .foregroundStyle(style.textSecondary)
                Text(ticket.passenger)
                    .font(.playfair(size: 15 * s, italic: true))
                    .foregroundStyle(style.textPrimary)
                    .lineLimit(1)
            }.padding(.top,12)

            Spacer()

            VStack(alignment: .trailing, spacing: 4 * s) {
                Text(ticket.ticketNumber)
                    .font(.system(size: 7.5 * s, weight: .light))
                    .tracking(0.6 * s)
                    .foregroundStyle(style.textSecondary)

                classChip(scale: s)
            }
            
        }
    }

    private func classChip(scale s: CGFloat) -> some View {
        Text(ticket.cabinClass.uppercased())
            .font(.system(size: 7 * s, weight: .medium))
            .tracking(0.7 * s)
            .foregroundStyle(style.onAccent)
            .padding(8 * s)
            .background(
                RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
                    .fill(style.accent.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
                    .strokeBorder(style.onAccent, lineWidth: 0.75 * s)
            )
    }

    // MARK: - Details grid (2 cols × 2 rows)

    private func detailsGrid(scale s: CGFloat) -> some View {
        VStack(spacing: 12 * s) {
            HStack(alignment: .top, spacing: 0) {
                detailCell(label: "DATE",    value: ticket.date,          scale: s, alignment: .leading)
                detailCell(label: "DEPARTS", value: ticket.departureTime, scale: s, alignment: .trailing)
            }
            HStack(alignment: .top, spacing: 0) {
                detailCell(label: "CARRIAGE", value: ticket.carriage, scale: s, alignment: .leading)
                detailCell(label: "SEAT",     value: ticket.seat,     scale: s, alignment: .trailing)
            }
        }
    }

    private func detailCell(
        label: String,
        value: String,
        scale s: CGFloat,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 3 * s) {
            Text(label)
                .font(.system(size: 6.5 * s, weight: .regular))
                .tracking(0.975 * s)
                .foregroundStyle(style.textSecondary)
            Text(value)
                .font(.playfair(size: 12 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12 * s)
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    // MARK: - Made with strip (full-width, masked by ticket shape)

    private func madeWithStrip(scale s: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        // Full-ticket sized so the mask (the ticket silhouette) aligns
        // 1:1. MadeWithLumoria sits full-width at the very bottom; the
        // ticket shape carves the visible strip so it follows every
        // notch and rounded corner in the artwork.
        ZStack(alignment: .bottom) {
            Color.clear
            MadeWithLumoria(
                style: .black,
                version: .full,
                scale: s,
                fullWidth: true
            )
        }
        .frame(width: w, height: h)
        .mask {
            if let base = style.backgroundAsset {
                Image("\(base)-vertical")
                    .resizable()
                    .frame(width: w, height: h)
            } else {
                Color.black.frame(width: w, height: h)
            }
        }
    }
}

// MARK: - Preview

#Preview("Orient — vertical") {
    OrientTicketVerticalView(ticket: OrientTicket(
        company: "Venice Simplon Orient Express",
        cabinClass: "Class",
        originCity: "Venice",
        originStation: "Santa Lucia",
        destinationCity: "Paris",
        destinationStation: "Gare de Lyon",
        passenger: "Passenger name",
        ticketNumber: "Ticket number",
        date: "4 May 2026",
        departureTime: "19:10",
        carriage: "7",
        seat: "A"
    ))
    .padding(24)
    .background(Color.Background.default)
}
