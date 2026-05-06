//
//  LumiereTicketVerticalView.swift
//  Lumoria App
//
//  Vertical "Lumiere" movie-category ticket — same language as the
//  horizontal variant, laid out portrait. Poster fills the upper
//  ~360pt of the 260×455 stub, fading to black so the title block and
//  3×3 details grid sit on solid black at the bottom.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=374-396
//

import SwiftUI

struct LumiereTicketVerticalView: View {
    let ticket: LumiereTicket
    var style: TicketStyleVariant = TicketTemplateKind.lumiere.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260
            let posterHeight: CGFloat = 360 * s

            ZStack(alignment: .topLeading) {
                (style.backgroundColor ?? Color.black)
                    .frame(width: w, height: h)

                LumierePoster(urlString: ticket.posterUrl, title: ticket.movieTitle)
                    .frame(width: w, height: posterHeight)
                    .overlay(
                        // Fades into the variant background so the
                        // poster bleeds cleanly into the bottom half
                        // regardless of theme (cream on Reel /
                        // Matinee, black on the dark variants).
                        LinearGradient(
                            stops: [
                                .init(color: (style.backgroundColor ?? .black).opacity(0), location: 0),
                                .init(color: style.backgroundColor ?? .black, location: 0.7),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipped()

                titleBlock(scale: s)
                    .padding(.leading, 16 * s)
                    .padding(.top, 246 * s)

                detailsGrid(scale: s)
                    .frame(width: 228 * s, alignment: .topLeading)
                    .padding(.leading, 16 * s)
                    .padding(.top, 335 * s)

                if showsLumoriaWatermark {
                    MadeWithLumoria(style: .white, version: .small, scale: s)
                        .padding(.top, 12 * s)
                        .padding(.trailing, 12 * s)
                        .frame(width: w, height: h, alignment: .topTrailing)
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 24 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Title block

    private func titleBlock(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4 * s) {
            Text("NOW SHOWING")
                .font(LumiereFont.barlow(size: 7.5 * s, weight: .regular))
                .tracking(1.4 * s)
                .foregroundStyle(style.accent)

            Text(ticket.movieTitle.uppercased())
                .font(LumiereFont.barlow(size: 29 * s, weight: .black))
                .tracking(-1.24 * s)
                .foregroundStyle(style.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            if !ticket.director.isEmpty {
                Text(ticket.director)
                    .font(LumiereFont.barlow(size: 10.5 * s, weight: .light))
                    .tracking(0.42 * s)
                    .foregroundStyle(style.textPrimary.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .frame(width: 228 * s, alignment: .leading)
    }

    // MARK: - Details grid

    private func detailsGrid(scale s: CGFloat) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 4 * s, verticalSpacing: 8 * s) {
            GridRow {
                detailCell(label: "Date",      value: ticket.date, scale: s)
                detailCell(label: "Screening", value: ticket.time, scale: s)
                Color.clear
                    .gridCellUnsizedAxes([.horizontal, .vertical])
            }
            GridRow {
                detailCell(label: "Room", value: ticket.roomNumber, scale: s)
                detailCell(label: "Row",  value: ticket.row,        scale: s)
                detailCell(label: "Seat", value: ticket.seat,       scale: s)
            }
            GridRow {
                detailCell(label: "Cinema", value: ticket.cinemaLocation, scale: s)
                    .gridCellColumns(3)
            }
        }
    }

    private func detailCell(
        label: String,
        value: String,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).textCase(.uppercase)
                .font(LumiereFont.barlow(size: 7 * s, weight: .regular))
                .tracking(1.05 * s)
                .foregroundStyle(style.accent)
            Text(value)
                .font(LumiereFont.barlow(size: 12 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

private let lumierePreviewTicketV = LumiereTicket(
    movieTitle: "Dune Part Two",
    director: "Denis Villeneuve",
    cinemaLocation: "Pathé Beaugrenelle",
    date: "21 Jun 2026",
    time: "20:30",
    roomNumber: "12",
    row: "K",
    seat: "14",
    posterUrl: ""
)

#Preview("Lumiere — vertical") {
    LumiereTicketVerticalView(ticket: lumierePreviewTicketV)
        .padding(32)
        .background(Color.Background.default)
}
