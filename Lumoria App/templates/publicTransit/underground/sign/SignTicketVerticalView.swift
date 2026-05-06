//
//  SignTicketVerticalView.swift
//  Lumoria App
//
//  Vertical public-transport ticket — "sign" style. Cream paper
//  stub runs across the top with a 2×2 grid (TICKET / FARE /
//  ZONES / ONE WAY), a horizontal perforation tear-line divides
//  stub from main body, and the main body carries the green header
//  stripe ("ONE WAY" + line pill), dot-and-line route connector,
//  FROM / TO stations, and a stops pill + black Made-with-Lumoria
//  pill along the bottom.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=266-2340
//

import SwiftUI

struct SignTicketVerticalView: View {
    let ticket: UndergroundTicket

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            // Single asset doubles as paper artwork and as an alpha
            // mask for every overlay so the line-colour header stripe
            // and text clip cleanly to the notched ticket shape.
            let bgMask = Image("sign-bg-vertical").resizable().frame(width: w, height: h)

            ZStack(alignment: .topLeading) {
                // Base paper artwork.
                Image("sign-bg-vertical")
                    .resizable()
                    .frame(width: w, height: h)

                // Overlays — clipped to the artwork's alpha via the
                // shared mask below.
                ZStack(alignment: .topLeading) {
                // 2×2 stub grid at (22, 20). Row 1: TICKET | FARE.
                // Row 2: ZONES | ONE WAY. Each cell is locked to
                // 40pt tall so a maxHeight-greedy child can't
                // stretch the grid into the main body.
                VStack(spacing: 8 * s) {
                    HStack(spacing: 8 * s) {
                        stubCell(label: "Ticket", value: ticket.ticketNumber, scale: s)
                        stubCell(label: "Fare",   value: ticket.fare,         scale: s)
                    }
                    .frame(height: 40 * s)
                    HStack(spacing: 8 * s) {
                        stubCell(label: "Zones", value: ticket.zones, scale: s)
                        Text("ONE WAY")
                            .font(.system(size: 14 * s, weight: .black))
                            .tracking(2.52 * s)
                            .foregroundStyle(lineAccent)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(height: 40 * s)
                }
                .padding(.horizontal, 22 * s)
                .padding(.top, 20 * s)
                .frame(
                    maxWidth: .infinity, maxHeight: .infinity,
                    alignment: .topLeading
                )

                // Line-colour header stripe on the main body
                // (y = 131 … 173). Pushed down 2pt from the Figma
                // y=129 so the stripe clears the perforation notch
                // silhouette baked into the artwork.
                Rectangle()
                    .fill(lineAccent)
                    .frame(height: 42 * s)
                    .padding(.top, 130 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .top
                    )

                // ONE WAY (white) in the main header.
                Text("ONE WAY")
                    .font(.system(size: 14 * s, weight: .black))
                    .tracking(2.52 * s)
                    .foregroundStyle(.white)
                    .padding(.leading, 18 * s)
                    .padding(.top, 144 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Line pill in the main header.
                linePill(scale: s)
                    .padding(.leading, 110 * s)
                    .padding(.top, 141 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // FROM dot
                Circle()
                    .stroke(lineAccent, lineWidth: 2.5 * s)
                    .frame(width: 10 * s, height: 10 * s)
                    .padding(.leading, 16 * s)
                    .padding(.top, 219 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Connector line
                Rectangle()
                    .fill(lineAccent.opacity(0.35))
                    .frame(width: 2 * s, height: 77 * s)
                    .padding(.leading, 20 * s)
                    .padding(.top, 229 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // TO dot
                Circle()
                    .fill(lineAccent)
                    .frame(width: 10 * s, height: 10 * s)
                    .padding(.leading, 16 * s)
                    .padding(.top, 305 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // FROM label + station
                Text("FROM")
                    .font(.system(size: 8 * s, weight: .bold))
                    .tracking(2.24 * s)
                    .foregroundStyle(muted)
                    .padding(.leading, 38 * s)
                    .padding(.top, 204 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                Text(ticket.originStation)
                    .font(.system(size: heroStationFont * s, weight: .heavy))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 206 * s, alignment: .leading)
                    .padding(.leading, 38 * s)
                    .padding(.top, 218 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                Text("TO")
                    .font(.system(size: 8 * s, weight: .bold))
                    .tracking(2.24 * s)
                    .foregroundStyle(muted)
                    .padding(.leading, 38 * s)
                    .padding(.top, 291 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                Text(ticket.destinationStation)
                    .font(.system(size: heroStationFont * s, weight: .heavy))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 206 * s, alignment: .leading)
                    .padding(.leading, 38 * s)
                    .padding(.top, 305 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Bottom row — stops pill + made-with.
                HStack(spacing: 12 * s) {
                    stopsPill(scale: s)
                    Spacer(minLength: 0)
                    if showsLumoriaWatermark {
                        MadeWithLumoria(style: .black, version: .small, scale: s)
                    }
                }
                .frame(height: 24 * s)
                .padding(.horizontal, 16 * s)
                .padding(.top, 414 * s)
                .frame(
                    maxWidth: .infinity, maxHeight: .infinity,
                    alignment: .topLeading
                )
                }
                .frame(width: w, height: h)
                .mask(bgMask)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 32 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Sub-views

    private func linePill(scale s: CGFloat) -> some View {
        Text(ticket.lineShortName)
            .font(.system(size: 12 * s, weight: .black))
            .tracking(0.72 * s)
            .foregroundStyle(lineAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(minWidth: 18 * s)
            .padding(.horizontal, 16 * s)
            .padding(.vertical, 4 * s)
            .background(
                RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
                    .fill(Color.white)
            )
    }

    private func stopsPill(scale s: CGFloat) -> some View {
        Text(stopsLabel)
            .font(.system(size: 11 * s, weight: .bold))
            .tracking(0.66 * s)
            .foregroundStyle(lineAccent)
            .lineLimit(1)
            .padding(.horizontal, 16 * s)
            .frame(height: 24 * s)
            .background(
                RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                    .fill(lineAccent.opacity(0.12))
            )
    }

    private var stopsLabel: String {
        ticket.stopsCount == 1
            ? String(localized: "1 STOP", locale: .ticket)
            : String(localized: "\(ticket.stopsCount) STOPS", locale: .ticket)
    }

    private func stubCell(
        label: String,
        value: String,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 7 * s, weight: .bold))
                .tracking(1.75 * s)
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 13 * s, weight: .heavy))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(8 * s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8 * s, style: .continuous)
                .fill(Color.black.opacity(0.03))
        )
    }

    // MARK: - Colors

    /// All line-coloured accents (header stripe, FROM/TO dots and
    /// connector, line pill, stops pill, stub "ONE WAY") derive
    /// from the ticket's `lineColor`.
    private var lineAccent: Color { Color(hex: ticket.lineColor) }
    private var ink: Color { Color(red: 0.12, green: 0.10, blue: 0.08) }
    private var muted: Color { Color(red: 0.45, green: 0.40, blue: 0.32) }

    private var heroStationFont: CGFloat {
        transitStationFontSize(
            origin: ticket.originStation,
            destination: ticket.destinationStation
        )
    }
}

#Preview("Sign · U1") {
    SignTicketVerticalView(
        ticket: UndergroundTicket(
            lineShortName: "U1",
            lineName: "U1 Leopoldau – Reumannplatz",
            companyName: "Wiener Linien",
            lineColor: "#E4002B",
            originStation: "Stephansplatz",
            destinationStation: "Karlsplatz",
            stopsCount: 5,
            date: "15 Jul 2026",
            ticketNumber: "987654",
            zones: "All zones",
            fare: "2.50 €",
            mode: 1
        )
    )
    .padding(24)
    .background(Color.Background.elevated)
}
