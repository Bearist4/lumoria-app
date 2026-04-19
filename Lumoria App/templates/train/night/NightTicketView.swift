//
//  NightTicketView.swift
//  Lumoria App
//
//  Horizontal "Night" train ticket — split card: main content on the
//  left 2/3, summary stub on the right 1/3. Starfield / moon / split
//  silhouette live in the bg artwork; everything else is code-drawn.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=8-1226
//

import SwiftUI

struct NightTicketView: View {
    let ticket: NightTicket
    var style: TicketStyleVariant = TicketTemplateKind.night.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260
    /// Fraction of the total width occupied by the right-hand stub.
    private let stubFraction: CGFloat = 0.34

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .topLeading) {
                // Full-bleed artwork: navy sky, stars, moon, split
                // silhouette, dashed divider.
                if let asset = style.backgroundAsset {
                    Image(asset)
                        .resizable()
                        .frame(width: w, height: h)
                }

                HStack(spacing: 0) {
                    mainSection(scale: s)
                        .frame(width: w * (1 - stubFraction))

                    stubSection(scale: s)
                        .frame(width: w * stubFraction)
                }
                .frame(width: w, height: h)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 24 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Main section (header + cities + field cards)

    private func mainSection(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8 * s) {
            headerRow(scale: s)
                .padding(.horizontal, 24 * s)
                .padding(.top, 16 * s)

            Spacer(minLength: 0)

            citiesRow(scale: s)
                .padding(.horizontal, 24 * s)
                .padding(.bottom, 24 * s)

            Spacer(minLength: 0)

            fieldCards(scale: s)
                .padding(.horizontal, 24 * s)
                .padding(.bottom, 16 * s)
        }
    }

    // MARK: - Header (company + code pill)

    private func headerRow(scale s: CGFloat) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text(ticket.company.uppercased())
                    .font(.system(size: 6 * s, weight: .bold))
                    .foregroundStyle(style.accent)
                    .lineLimit(1)
                Text(ticket.trainType)
                    .font(.system(size: 8 * s, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer()

            Text(ticket.trainCode)
                .font(.system(size: 9 * s, weight: .bold))
                .foregroundStyle(style.onAccent)
                .padding(.horizontal, 10 * s)
                .padding(.vertical, 3 * s)
                .background(
                    RoundedRectangle(cornerRadius: 8 * s, style: .continuous)
                        .fill(style.accent)
                )
        }
    }

    // MARK: - Cities row (origin + destination)

    private func citiesRow(scale s: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            cityBlock(
                city: ticket.originCity,
                station: ticket.originStation,
                alignment: .leading,
                scale: s
            )
            cityBlock(
                city: ticket.destinationCity,
                station: ticket.destinationStation,
                alignment: .trailing,
                scale: s
            )
        }
    }

    private func cityBlock(
        city: String,
        station: String,
        alignment: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(city)
                .font(.system(size: 24 * s, weight: .bold))
                .tracking(-1.2 * s)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(station)
                .font(.system(size: 8 * s, weight: .regular))
                .tracking(0.72 * s)
                .foregroundStyle(style.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    // MARK: - Field cards (passenger + car/berth + date/ticket)

    private func fieldCards(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8 * s) {
            fieldCard(label: "Passenger", value: ticket.passenger, scale: s)

            HStack(alignment: .top, spacing: 8 * s) {
                fieldCard(label: "Car",   value: ticket.car,   scale: s)
                fieldCard(label: "Berth", value: ticket.berth, scale: s)
            }

            HStack(alignment: .top, spacing: 8 * s) {
                fieldCard(label: "Departs",   value: ticket.date,         scale: s)
                fieldCard(label: "Ticket No.", value: ticket.ticketNumber, scale: s)
            }
        }
    }

    private func fieldCard(label: String, value: String, scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: 6 * s, weight: .regular))
                .tracking(1.44 * s)
                .foregroundStyle(style.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.system(size: 10 * s, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.9))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 9 * s)
        .padding(.vertical, 5 * s)
        .background(
            RoundedRectangle(cornerRadius: 8 * s, style: .continuous)
                .fill(Color(red: 60/255, green: 90/255, blue: 200/255).opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8 * s, style: .continuous)
                .strokeBorder(
                    Color(red: 80/255, green: 120/255, blue: 255/255).opacity(0.12),
                    lineWidth: 0.75 * s
                )
        )
    }

    // MARK: - Stub (right side)

    private func stubSection(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16 * s) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 7 * s) {
                Text("Train type".uppercased())
                    .font(.system(size: 8 * s, weight: .regular))
                    .tracking(1.44 * s)
                    .foregroundStyle(Color.white.opacity(0.45))

                Text("\(ticket.originCity) → \(ticket.destinationCity)")
                    .font(.system(size: 14 * s, weight: .bold))
                    .foregroundStyle(style.accent.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text("Car \(ticket.car) · \(ticket.berth) Berth".uppercased())
                    .font(.system(size: 8 * s, weight: .regular))
                    .tracking(1.44 * s)
                    .foregroundStyle(style.accent.opacity(0.4))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            if showsLumoriaWatermark {
                MadeWithLumoria(style: .white, version: .small, scale: s)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16 * s)
        .padding(.vertical, 24 * s)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

// MARK: - Preview

private let nightPreviewTicket = NightTicket(
    company: "Company",
    trainType: "Train type",
    trainCode: "Train Code",
    originCity: "Vienna",
    originStation: "Wien Hauptbahnhof",
    destinationCity: "Paris",
    destinationStation: "Gare de l'Est",
    passenger: "Jane Doe",
    car: "37",
    berth: "Lower",
    date: "14 Mar 2026 · 22:04",
    ticketNumber: "000000000000"
)

#Preview("Night — horizontal") {
    NightTicketView(ticket: nightPreviewTicket)
        .padding(24)
        .background(Color.Background.default)
}
