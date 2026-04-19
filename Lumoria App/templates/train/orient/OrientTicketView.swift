//
//  OrientTicketView.swift
//  Lumoria App
//
//  Horizontal Orient-Express-style train ticket: deep navy field with
//  a thin gold inner border, Playfair Display serif heroes, and a
//  diamond rule between the two cities.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=21-515
//

import SwiftUI

struct OrientTicketView: View {
    let ticket: OrientTicket
    var style: TicketStyleVariant = TicketTemplateKind.orient.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .topLeading) {
                // Full-bleed artwork — contains the navy field, the
                // inner gold border, and the top/bottom tinted bars.
                if let asset = style.backgroundAsset {
                    Image(asset)
                        .resizable()
                        .frame(width: w, height: h)
                }

                VStack(alignment: .leading, spacing: 0) {
                    headerRow(scale: s)
                        .padding(.horizontal, 24 * s)
                        .padding(.top, 20 * s)
                        .frame(height: 48 * s)

                    Spacer(minLength: 0)
                    journeyRow(scale: s)
                        .padding(.horizontal, 58 * s)
                    Spacer(minLength: 0)

                    passengerRow(scale: s)
                        .padding(.horizontal, 58 * s)

                    Spacer(minLength: 0)

                    detailsBar(scale: s)
                }
                .padding(.bottom, 8 * s)
                .frame(width: w, height: h, alignment: .topLeading)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 24 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Header (company + class chip)

    private func headerRow(scale s: CGFloat) -> some View {
        HStack(alignment: .center) {
            madeWithBadge(scale: s)

            Spacer()

            classChip(scale: s)
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

    // MARK: - Journey (origin · diamond · destination)

    private func journeyRow(scale s: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
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
        .padding(.top, 8 * s)
    }

    

    // MARK: - Passenger row

    private func passengerRow(scale s: CGFloat) -> some View {
        HStack(alignment: .center) {
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
            }.padding(.top, 16)

            Spacer()

            Text(ticket.ticketNumber)
                .font(.system(size: 7.5 * s, weight: .light))
                .tracking(0.6 * s)
                .foregroundStyle(style.textSecondary)
        }
    }

    // MARK: - Bottom details bar

    private func detailsBar(scale s: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            detailCell(label: "DATE",     value: ticket.date,          scale: s)
            detailCell(label: "DEPARTS",  value: ticket.departureTime, scale: s)
            detailCell(label: "CARRIAGE", value: ticket.carriage,      scale: s)
            detailCell(label: "SEAT",     value: ticket.seat,          scale: s)
        }
        .padding(.horizontal, 28 * s)
        .padding(.vertical, 12 * s)
    }

    @ViewBuilder
    private func madeWithBadge(scale s: CGFloat) -> some View {
        if showsLumoriaWatermark {
            MadeWithLumoria(style: .white, version: .small, scale: s)
        }
    }

    private func detailCell(label: String, value: String, scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3 * s) {
            Text(label)
                .font(.system(size: 6.5 * s, weight: .regular))
                .tracking(0.975 * s)
                .foregroundStyle(style.textSecondary)
            Text(value)
                .font(.playfair(size: 12 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

// MARK: - Preview

private let orientPreviewTicket = OrientTicket(
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
)

#Preview("Orient — horizontal") {
    OrientTicketView(ticket: orientPreviewTicket)
        .padding(24)
        .background(Color.Background.default)
}
