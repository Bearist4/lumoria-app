//
//  ExpressTicketVerticalView.swift
//  Lumoria App
//
//  Vertical Shinkansen-style train ticket. Same content as the horizontal
//  variant, restacked into a portrait silhouette with red border bands at
//  the top and bottom and a downward arrow between the cities.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=26-1456
//

import SwiftUI

struct ExpressTicketVerticalView: View {
    let ticket: ExpressTicket
    var style: TicketStyleVariant = TicketTemplateKind.express.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack(alignment: .top) {
                Color(hex: "FAFAFA")

                VStack(spacing: 0) {
                    style.accent.frame(height: 12 * s)

                    VStack(alignment: .leading, spacing: 0) {
                        trainInfoRow(scale: s)
                        Spacer(minLength: 0)
                        citiesColumn(scale: s)
                        Spacer(minLength: 0)
                        detailsGrid(scale: s)
                        Spacer(minLength: 0)
                        footerColumn(scale: s)
                    }
                    .padding(24 * s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    style.accent.frame(height: 12 * s)
                }
                .frame(width: w, height: h)

                classPill(scale: s)
                    .padding(.top, 20 * s)
                    .padding(.trailing, 24 * s)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 16 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Train info

    private func trainInfoRow(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4 * s) {
            Text(ticket.trainType.uppercased())
                .font(.system(size: 8 * s, weight: .regular))
                .tracking(2 * s)
                .foregroundStyle(style.accent)
                .lineLimit(1)
            Text(ticket.trainNumber)
                .font(.system(size: 11 * s, weight: .medium))
                .tracking(0.22 * s)
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
        }
    }

    // MARK: - Class pill

    private func classPill(scale s: CGFloat) -> some View {
        Text(ticket.cabinClass.uppercased())
            .font(.system(size: 8 * s, weight: .bold))
            .foregroundStyle(style.onAccent)
            .padding(.horizontal, 8 * s)
            .padding(.vertical, 4 * s)
            .background(
                RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
                    .fill(style.accent)
            )
    }

    // MARK: - Cities (origin · arrow ↓ · destination, stacked)

    private func citiesColumn(scale s: CGFloat) -> some View {
        let kanjiSize = ExpressKanjiSizing.size(
            for: [ticket.originCityKanji, ticket.destinationCityKanji],
            base: 44 * s
        )

        return VStack(alignment: .leading, spacing: 16 * s) {
            cityBlock(
                latin: ticket.originCity,
                kanji: ticket.originCityKanji,
                kanjiSize: kanjiSize,
                scale: s
            )

            HStack(alignment: .center, spacing: 0) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 14 * s, weight: .regular))
                    .foregroundStyle(style.accent)

                Spacer(minLength: 0)

                madeWithBadge(scale: s)
            }

            cityBlock(
                latin: ticket.destinationCity,
                kanji: ticket.destinationCityKanji,
                kanjiSize: kanjiSize,
                scale: s
            )
        }
    }

    private func cityBlock(
        latin: String,
        kanji: String,
        kanjiSize: CGFloat,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(latin.uppercased())
                .font(.system(size: 11 * s, weight: .light))
                .tracking(3.3 * s)
                .foregroundStyle(style.textSecondary)
                .lineLimit(1)
            Text(kanji)
                .font(.system(size: kanjiSize, weight: .black))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - Details grid (3 cols × 2 rows)

    private func detailsGrid(scale s: CGFloat) -> some View {
        let cols: [GridItem] = Array(
            repeating: GridItem(.flexible(), spacing: 8 * s, alignment: .topLeading),
            count: 3
        )
        return LazyVGrid(columns: cols, alignment: .leading, spacing: 8 * s) {
            detailCell(kanji: "乗車日",   en: "Date",    value: ticket.date,          scale: s)
            detailCell(kanji: "発車時刻", en: "Departs", value: ticket.departureTime, scale: s)
            detailCell(kanji: "到着",    en: "Arrives", value: ticket.arrivalTime,   scale: s)
            detailCell(kanji: "号車",    en: "Car",     value: ticket.car,           scale: s)
            detailCell(kanji: "席",      en: "Seat",    value: ticket.seat,          scale: s)
            Color.clear
        }
    }

    private func detailCell(
        kanji: String,
        en: String,
        value: String,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4 * s) {
            HStack(spacing: 4 * s) {
                Text(kanji)
                    .font(.system(size: 6.5 * s, weight: .regular))
                    .tracking(0.325 * s)
                    .foregroundStyle(style.textSecondary)
                Text(en.uppercased())
                    .font(.system(size: 6.5 * s, weight: .regular))
                    .tracking(0.325 * s)
                    .foregroundStyle(style.textSecondary)
            }
            Text(value)
                .font(.system(size: 11 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
        }
    }

    // MARK: - Footer column

    private func footerColumn(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4 * s) {
            bilingualLine(kanji: "新幹線", en: "RESERVED SEAT TICKET", scale: s)
            bilingualLine(kanji: "新幹線", en: "VALID FOR SINGLE JOURNEY", scale: s)

            Text(ticket.ticketNumber)
                .font(.system(size: 6 * s, weight: .regular))
                .foregroundStyle(style.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 8 * s)
        }
    }

    private func bilingualLine(kanji: String, en: String, scale s: CGFloat) -> some View {
        HStack(spacing: 4 * s) {
            Text(kanji)
                .font(.system(size: 7 * s, weight: .light))
                .tracking(0.35 * s)
                .foregroundStyle(style.textSecondary)
            Text(en)
                .font(.system(size: 7 * s, weight: .light))
                .tracking(0.35 * s)
                .foregroundStyle(style.textSecondary)
        }
    }

    @ViewBuilder
    private func madeWithBadge(scale s: CGFloat) -> some View {
        if showsLumoriaWatermark {
            MadeWithLumoria(style: .black, version: .small, scale: s)
        }
    }
}

// MARK: - Preview

#Preview("Express — vertical") {
    ExpressTicketVerticalView(ticket: ExpressTicket(
        trainType: "Shinkansen",
        trainNumber: "Hikari 503",
        cabinClass: "Class",
        originCity: "Tokyo",
        originCityKanji: "東京",
        destinationCity: "Osaka",
        destinationCityKanji: "大阪",
        date: "14.03.2026",
        departureTime: "06:33",
        arrivalTime: "09:10",
        car: "7",
        seat: "14A",
        ticketNumber: "0000000000"
    ))
    .padding(24)
    .background(Color.Background.default)
}
