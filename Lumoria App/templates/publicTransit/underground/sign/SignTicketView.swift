//
//  SignTicketView.swift
//  Lumoria App
//
//  Horizontal public-transport ticket — "sign" style. Cream paper
//  ticket with a green header stripe on the main body, a perforated
//  tear-off stub on the right carrying TICKET / ZONES / FARE
//  stacked cards, a dot-and-line route connector, and a green
//  `{stops} STOPS` pill paired with a black Made-with-Lumoria pill
//  along the bottom. Reads like a printed rail / tram ticket from
//  a platform vending machine.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=266-2341
//

import SwiftUI

struct SignTicketView: View {
    let ticket: UndergroundTicket

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            // Single asset used as both the visible paper artwork
            // and the alpha mask for every overlay above it. Where
            // the asset is transparent (rounded corners, perforation
            // notches) the line-colour stripe and text are clipped
            // away automatically.
            let bgMask = Image("sign-bg").resizable().frame(width: w, height: h)

            ZStack(alignment: .topLeading) {
                // Base paper artwork.
                Image("sign-bg")
                    .resizable()
                    .frame(width: w, height: h)

                // Every overlay shares one mask so the line-colour
                // header and accents respect the notched shape.
                ZStack(alignment: .topLeading) {
                    // Line-colour header stripe across the main body.
                    Rectangle()
                        .fill(lineAccent)
                        .frame(width: 325 * s, height: 44 * s)
                        .frame(
                            maxWidth: .infinity, maxHeight: .infinity,
                            alignment: .topLeading
                        )

                // Header — main side
                Text("ONE WAY")
                    .font(.system(size: 14 * s, weight: .black))
                    .tracking(2.52 * s)
                    .foregroundStyle(.white)
                    .padding(.leading, 24 * s)
                    .padding(.top, 16 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                linePill(scale: s)
                    .padding(.leading, 116 * s)
                    .padding(.top, 13 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Company name — right-aligned inside main body
                // (ends at x=310 = 325 − 15).
                Text(ticket.companyName)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(1.4 * s)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: 180 * s, alignment: .trailing)
                    .padding(.leading, 130 * s)
                    .padding(.top, 18 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // FROM dot
                Circle()
                    .stroke(lineAccent, lineWidth: 2.5 * s)
                    .frame(width: 10 * s, height: 10 * s)
                    .padding(.leading, 24 * s)
                    .padding(.top, 94 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Connector line between dots
                Rectangle()
                    .fill(lineAccent.opacity(0.35))
                    .frame(width: 2 * s, height: 42 * s)
                    .padding(.leading, 28 * s)
                    .padding(.top, 104 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // TO dot
                Circle()
                    .fill(lineAccent)
                    .frame(width: 10 * s, height: 10 * s)
                    .padding(.leading, 24 * s)
                    .padding(.top, 148 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // FROM label + station
                Text("FROM")
                    .font(.system(size: 8 * s, weight: .bold))
                    .tracking(2.24 * s)
                    .foregroundStyle(muted)
                    .padding(.leading, 46 * s)
                    .padding(.top, 79 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                Text(ticket.originStation)
                    .font(.system(size: 22 * s, weight: .heavy))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 240 * s, alignment: .leading)
                    .padding(.leading, 46 * s)
                    .padding(.top, 93 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // TO label + station
                Text("TO")
                    .font(.system(size: 8 * s, weight: .bold))
                    .tracking(2.24 * s)
                    .foregroundStyle(muted)
                    .padding(.leading, 46 * s)
                    .padding(.top, 133 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                Text(ticket.destinationStation)
                    .font(.system(size: 22 * s, weight: .heavy))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 240 * s, alignment: .leading)
                    .padding(.leading, 46 * s)
                    .padding(.top, 147 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Bottom row — stops pill + made-with
                HStack(spacing: 12 * s) {
                    stopsPill(scale: s)
                    Spacer(minLength: 0)
                    if showsLumoriaWatermark {
                        MadeWithLumoria(style: .black, version: .small, scale: s)
                    }
                }
                .frame(width: 285 * s, height: 24 * s, alignment: .leading)
                .padding(.leading, 24 * s)
                .padding(.top, 220 * s)
                .frame(
                    maxWidth: .infinity, maxHeight: .infinity,
                    alignment: .topLeading
                )

                // Stub — ONE WAY header (line colour)
                Text("ONE WAY")
                    .font(.system(size: 14 * s, weight: .black))
                    .tracking(2.52 * s)
                    .foregroundStyle(lineAccent)
                    .padding(.leading, 349 * s)
                    .padding(.top, 16 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                    // Stub fields (TICKET / ZONES / FARE)
                    VStack(spacing: 8 * s) {
                        stubCell(label: "TICKET", value: ticket.ticketNumber, scale: s)
                        stubCell(label: "ZONES",  value: ticket.zones,        scale: s)
                        stubCell(label: "FARE",   value: ticket.fare,         scale: s)
                    }
                    .frame(width: 104 * s)
                    .padding(.leading, 338 * s)
                    .padding(.top, 49 * s)
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
            ? String(localized: "1 STOP")
            : String(localized: "\(ticket.stopsCount) STOPS")
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
    /// from the ticket's `lineColor` so each operator's ticket
    /// repaints itself from its own brand red / blue / green.
    private var lineAccent: Color { Color(hex: ticket.lineColor) }
    private var ink: Color { Color(red: 0.12, green: 0.10, blue: 0.08) }
    private var muted: Color { Color(red: 0.45, green: 0.40, blue: 0.32) }
}

#Preview("Sign · U1") {
    SignTicketView(
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
    .background(Color.Background.default)
}
