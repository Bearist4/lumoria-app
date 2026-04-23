//
//  PostTicketView.swift
//  Lumoria App
//
//  Horizontal "Post" train ticket — cream paper with a hairline inner
//  rule, serif typography, two big city columns, and a Date / Depart /
//  Car / Seat row across the bottom.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=158-13024
//

import SwiftUI

struct PostTicketView: View {
    let ticket: PostTicket
    var style: TicketStyleVariant = TicketTemplateKind.post.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .topLeading) {
                // Cream paper + hairline inner border live in the asset
                // (single `post-bg` slot, re-used rotated on vertical).
                if let asset = style.backgroundAsset {
                    Image(asset)
                        .resizable()
                        .frame(width: w, height: h)
                } else {
                    style.swatch.background
                        .frame(width: w, height: h)
                }

                VStack(spacing: 0) {
                    headerRow(scale: s)
                        .frame(height: .infinity * s)

                    // Divider under header
                    Rectangle()
                        .fill(style.divider)
                        .frame(height: 1)
                        .padding(.horizontal, 8 * s)

                    citiesRow(scale: s)
                        .frame(maxHeight: .infinity)

                    // Divider above details
                    Rectangle()
                        .fill(style.divider)
                        .frame(height: 1)
                        .padding(.horizontal, 8 * s)

                    detailsRow(scale: s)
                        .frame(height: .infinity * s)
                }
                .frame(width: w, height: h)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 24 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Header (train info + made-with pill)

    private func headerRow(scale s: CGFloat) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3 * s) {
                Text(ticket.trainNumber.uppercased())
                    .font(.custom("TimesNewRomanPS-BoldMT", size: 6 * s))
                    .tracking(1.41 * s)
                    .foregroundStyle(style.textSecondary)
                    .lineLimit(1)
                Text(ticket.trainType)
                    .font(.custom("TimesNewRomanPS-BoldMT", size: 10 * s))
                    .tracking(0.47 * s)
                    .foregroundStyle(style.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            madeWithBadge(scale: s)
        }
        .padding(.horizontal, 48 * s)
        .padding(.top, 24 * s)
        .padding(.bottom, 16 * s)
    }

    @ViewBuilder
    private func madeWithBadge(scale s: CGFloat) -> some View {
        if showsLumoriaWatermark {
            MadeWithLumoria(style: .black, version: .small, scale: s)
        }
    }

    // MARK: - Cities (origin | destination) — hero row

    private func citiesRow(scale s: CGFloat) -> some View {
        HStack(spacing: 0) {
            cityBlock(
                label: "From",
                city: ticket.originCity,
                station: ticket.originStation,
                alignment: .leading,
                scale: s
            )
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(style.divider)
                    .frame(width: 1)
                    .padding(.vertical, 24 * s)
            }

            cityBlock(
                label: "To",
                city: ticket.destinationCity,
                station: ticket.destinationStation,
                alignment: .trailing,
                scale: s
            )
        }
        .padding(.horizontal, 8 * s)
    }

    private func cityBlock(
        label: String,
        city: String,
        station: String,
        alignment: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: alignment, spacing: 3 * s) {
            Text(label.uppercased())
                .font(.custom("TimesNewRomanPSMT", size: 6.3 * s))
                .tracking(0.88 * s)
                .foregroundStyle(style.textSecondary)

            Text(city)
                .font(.custom("TimesNewRomanPS-BoldMT", size: 25 * s))
                .tracking(-0.5 * s)
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(station.uppercased())
                .font(.custom("TimesNewRomanPSMT", size: 6.3 * s))
                .tracking(0.88 * s)
                .foregroundStyle(style.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .padding(.horizontal, 16 * s)
    }

    // MARK: - Details row (Date / Depart / Car / Seat)

    private func detailsRow(scale s: CGFloat) -> some View {
        HStack(spacing: 0) {
            detailCell(label: "Date",   value: ticket.date,          showDivider: false, scale: s)
            detailCell(label: "Depart", value: ticket.departureTime, showDivider: true,  scale: s)
            detailCell(label: "Car",    value: ticket.car,           showDivider: true,  scale: s)
            detailCell(label: "Seat",   value: ticket.seat,          showDivider: true,  scale: s)
        }
        .padding(.horizontal, 36 * s)
        .padding(.top, 16 * s)
        .padding(.bottom, 24 * s)
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
                    .fill(style.divider)
                    .frame(width: 1, height: 27 * s)
            }
            VStack(spacing: 3 * s) {
                Text(label.uppercased())
                    .font(.custom("TimesNewRomanPSMT", size: 6 * s))
                    .tracking(1.32 * s)
                    .foregroundStyle(style.textSecondary)
                Text(value)
                    .font(.custom("TimesNewRomanPS-BoldMT", size: 12 * s))
                    .foregroundStyle(style.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, showDivider ? 9 * s : 0)
        }
    }
}

// MARK: - Preview

private let postPreviewTicket = PostTicket(
    trainNumber: "Train 12345",
    trainType: "TGV Inoui",
    originCity: "Paris",
    originStation: "Gare du Nord",
    destinationCity: "Lyon",
    destinationStation: "Part-Dieu",
    date: "15 Jul. 2026",
    departureTime: "07:30",
    car: "12",
    seat: "E7"
)

#Preview("Post — horizontal") {
    PostTicketView(ticket: postPreviewTicket)
        .padding(24)
        .background(Color.Background.default)
}
