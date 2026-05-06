//
//  PostTicketVerticalView.swift
//  Lumoria App
//
//  Vertical "Post" train ticket — same cream paper & serif treatment
//  as the horizontal variant, restacked for portrait.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=158-13023
//

import SwiftUI

struct PostTicketVerticalView: View {
    let ticket: PostTicket
    var style: TicketStyleVariant = TicketTemplateKind.post.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack(alignment: .topLeading) {
                // Single `post-bg` slot shared with horizontal — rotated
                // 90° so the asset fits the portrait frame.
                if let asset = style.backgroundAsset {
                    Image(asset)
                        .resizable()
                        .frame(width: h, height: w)
                        .rotationEffect(.degrees(90))
                        .frame(width: w, height: h)
                } else {
                    style.swatch.background
                        .frame(width: w, height: h)
                }

                VStack(spacing: 0) {
                    headerRow(scale: s)
                        .padding(.horizontal, 36 * s)
                        .padding(.top, 21 * s)
                        .padding(.bottom, 16 * s)

                    Rectangle()
                        .fill(style.divider)
                        .frame(height: 1)
                        .padding(.horizontal, 8 * s)

                    cityBlock(
                        label: "From",
                        city: ticket.originCity,
                        station: ticket.originStation,
                        alignment: .leading,
                        scale: s
                    )
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 24 * s)

                    Rectangle()
                        .fill(style.divider)
                        .frame(height: 1)
                        .padding(.horizontal, 8 * s)

                    cityBlock(
                        label: "To",
                        city: ticket.destinationCity,
                        station: ticket.destinationStation,
                        alignment: .trailing,
                        scale: s
                    )
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 24 * s)

                    Rectangle()
                        .fill(style.divider)
                        .frame(height: 1)
                        .padding(.horizontal, 8 * s)

                    detailsGrid(scale: s)
                        .padding(.horizontal, 16 * s)
                        .padding(.vertical, 12 * s)
                        .frame(height: 96 * s)
                }
                .frame(width: w, height: h)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 24 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Header (centred train info + made-with pill)

    private func headerRow(scale s: CGFloat) -> some View {
        VStack(spacing: 8 * s) {
            madeWithBadge(scale: s)

            VStack(spacing: 3 * s) {
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
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func madeWithBadge(scale s: CGFloat) -> some View {
        if showsLumoriaWatermark {
            MadeWithLumoria(style: .black, version: .small, scale: s)
        }
    }

    // MARK: - City block (shared)

    private func cityBlock(
        label: String,
        city: String,
        station: String,
        alignment: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: alignment, spacing: 3 * s) {
            Text(label).textCase(.uppercase)
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
    }

    // MARK: - Details grid — 2×2

    private func detailsGrid(scale s: CGFloat) -> some View {
        VStack(spacing: 12 * s) {
            HStack(spacing: 0) {
                detailCell(label: "Date", value: ticket.date, scale: s)
                Rectangle()
                    .fill(style.divider)
                    .frame(width: 1, height: 27 * s)
                detailCell(label: "Car", value: ticket.car, scale: s)
            }
            HStack(spacing: 0) {
                detailCell(label: "Depart", value: ticket.departureTime, scale: s)
                Rectangle()
                    .fill(style.divider)
                    .frame(width: 1, height: 27 * s)
                detailCell(label: "Seat", value: ticket.seat, scale: s)
            }
        }
    }

    private func detailCell(
        label: String,
        value: String,
        scale s: CGFloat
    ) -> some View {
        VStack(spacing: 3 * s) {
            Text(label).textCase(.uppercase)
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
    }
}

// MARK: - Preview

#Preview("Post — vertical") {
    PostTicketVerticalView(ticket: PostTicket(
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
    ))
    .padding(24)
    .background(Color.Background.default)
}
