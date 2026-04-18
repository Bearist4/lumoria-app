//
//  ExpressTicketView.swift
//  Lumoria App
//
//  Horizontal Shinkansen-style train ticket. Bilingual headers (Latin
//  city above, kanji city as the hero), red top/bottom border bands,
//  bilingual field labels (kanji + EN).
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=16-515
//

import SwiftUI

struct ExpressTicketView: View {
    let ticket: ExpressTicket
    var style: TicketStyleVariant = TicketTemplateKind.express.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .top) {
                // Card body
                Color(hex: "FAFAFA")

                VStack(spacing: 0) {
                    // Top red band
                    style.accent.frame(height: 12 * s)

                    // Body
                    VStack(alignment: .leading, spacing: 0) {
                        trainInfoRow(scale: s)
                        Spacer(minLength: 0)
                        journeyRow(scale: s)
                        Spacer(minLength: 0)
                        detailsRow(scale: s)
                        Spacer(minLength: 0)
                        footerRow(scale: s)
                    }
                    .padding(.horizontal, 24 * s)
                    .padding(.vertical, 16 * s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    // Bottom red band
                    style.accent.frame(height: 12 * s)
                }
                .frame(width: w, height: h)

                // Class pill — overlaid top-right
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

    // MARK: - Train info (top-left)

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

    // MARK: - Journey (origin → arrow → destination)

    private func journeyRow(scale s: CGFloat) -> some View {
        let kanjiSize = ExpressKanjiSizing.size(
            for: [ticket.originCityKanji, ticket.destinationCityKanji],
            base: 44 * s
        )

        return HStack(alignment: .center, spacing: 28 * s) {
            cityBlock(
                latin: ticket.originCity,
                kanji: ticket.originCityKanji,
                kanjiSize: kanjiSize,
                alignment: .leading,
                scale: s
            )

            arrowGlyph(scale: s)

            cityBlock(
                latin: ticket.destinationCity,
                kanji: ticket.destinationCityKanji,
                kanjiSize: kanjiSize,
                alignment: .leading,
                scale: s
            )
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func cityBlock(
        latin: String,
        kanji: String,
        kanjiSize: CGFloat,
        alignment: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: alignment, spacing: 0) {
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

    private func arrowGlyph(scale s: CGFloat) -> some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 14 * s, weight: .regular))
            .foregroundStyle(style.accent)
    }

    // MARK: - Details row (Date / Departs / Arrives / Car / Seat)

    private func detailsRow(scale s: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 12 * s) {
            detailCell(kanji: "乗車日",   en: "Date",    value: ticket.date,          scale: s, leadingDivider: false)
            detailCell(kanji: "発車時刻", en: "Departs", value: ticket.departureTime, scale: s, leadingDivider: true)
            detailCell(kanji: "到着",    en: "Arrives", value: ticket.arrivalTime,   scale: s, leadingDivider: true)
            detailCell(kanji: "号車",    en: "Car",     value: ticket.car,           scale: s, leadingDivider: true)
            detailCell(kanji: "席",      en: "Seat",    value: ticket.seat,          scale: s, leadingDivider: true)
        }
    }

    private func detailCell(
        kanji: String,
        en: String,
        value: String,
        scale s: CGFloat,
        leadingDivider: Bool
    ) -> some View {
        HStack(spacing: 0) {
            if leadingDivider {
                Rectangle()
                    .fill(style.divider)
                    .frame(width: 1, height: 21 * s)
                    .padding(.trailing, 12 * s)
            }
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
            }
        }
    }

    // MARK: - Footer row (validity strings + ticket number + Made with)

    private func footerRow(scale s: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 12 * s) {
            VStack(alignment: .leading, spacing: 4 * s) {
                bilingualLine(kanji: "新幹線", en: "RESERVED SEAT TICKET", scale: s)
                bilingualLine(kanji: "新幹線", en: "VALID FOR SINGLE JOURNEY", scale: s)
            }

            Spacer()

            Text(ticket.ticketNumber)
                .font(.system(size: 6 * s, weight: .regular))
                .foregroundStyle(style.textSecondary)

            madeWithBadge(scale: s)
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
            MadeWithLumoria(style: .black, version: .small, scale: 0.44 * s)
        }
    }
}

// MARK: - Preview

private let expressPreviewTicket = ExpressTicket(
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
)

#Preview("Express — horizontal") {
    ExpressTicketView(ticket: expressPreviewTicket)
        .padding(24)
        .background(Color.Background.default)
}

#Preview("Express — long names") {
    // Stress-test the equal-size kanji sizing with a 4-char destination.
    ExpressTicketView(ticket: ExpressTicket(
        trainType: "Shinkansen",
        trainNumber: "Sakura 567",
        cabinClass: "Green",
        originCity: "Kagoshima",
        originCityKanji: "鹿児島",
        destinationCity: "Shin-Hakodate",
        destinationCityKanji: "新函館北斗",
        date: "14.03.2026",
        departureTime: "06:33",
        arrivalTime: "21:42",
        car: "11",
        seat: "3D",
        ticketNumber: "0000123456"
    ))
    .padding(24)
    .background(Color.Background.default)
}

// MARK: - Equal-size kanji sizing

/// Picks one font size for a set of CJK strings so the longest one
/// fits the layout — short strings then render at the *same* size as
/// the long one rather than each scaling independently. Character-count
/// based heuristic (kanji/katakana glyphs have near-uniform width).
enum ExpressKanjiSizing {
    static func size(for strings: [String], base: CGFloat) -> CGFloat {
        let maxChars = strings.map(\.count).max() ?? 0
        switch maxChars {
        case 0...2:  return base
        case 3:      return base * 0.82
        case 4:      return base * 0.68
        case 5:      return base * 0.58
        default:     return base * 0.5
        }
    }
}
