//
//  UndergroundTicketView.swift
//  Lumoria App
//
//  Horizontal subway / metro ticket — dark 455×260 card with a
//  line-coloured badge + line name at top-left, bold FROM → TO
//  station names stacked down the left, a tiny stop-count rail in
//  the margin, and an aside column on the right with ticket number,
//  zones, fare. Looks at home next to Wiener Linien, Tokyo Metro, TfL
//  and MTA visual identities.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=18-515
//

import SwiftUI

struct UndergroundTicketView: View {
    let ticket: UndergroundTicket

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260
    private let cardColor = Color(hex: "15151F")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .topLeading) {
                cardColor

                // Line header — badge + line / operator name.
                lineHeader(scale: s)
                    .padding(.leading, 16 * s)
                    .padding(.top, 16 * s)

                // Watermark pill — top-right.
                if showsLumoriaWatermark {
                    MadeWithLumoria(style: .white, version: .small, scale: 0.5)
                        .padding(.trailing, 16 * s)
                        .padding(.top, 16 * s)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Left margin: stop-count rail sits between FROM and TO.
                stopsRail(scale: s)
                    .padding(.leading, 16 * s)
                    .padding(.top, 98 * s)

                // FROM → TO hero block.
                journeyBlock(scale: s)
                    .padding(.leading, 49 * s)
                    .padding(.top, 74 * s)

                // Right aside — ticket / zones / fare.
                detailsAside(scale: s)
                    .frame(width: 123 * s, height: 144 * s)
                    .padding(.leading, 332 * s)
                    .padding(.top, 74 * s)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 32 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Line header

    private func lineHeader(scale s: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 12 * s) {
            lineBadge(scale: s)

            VStack(alignment: .leading, spacing: 4 * s) {
                Text(ticket.lineName.uppercased())
                    .font(.system(size: 9 * s, weight: .bold))
                    .tracking(1.35 * s)
                    .foregroundStyle(lineAccent)
                    .lineLimit(1)

                Text(ticket.companyName)
                    .font(.system(size: 8 * s, weight: .regular))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
            }
        }
    }

    private func lineBadge(scale s: CGFloat) -> some View {
        ZStack {
            Circle().fill(lineAccent)

            Text(ticket.lineShortName)
                .font(.system(size: 18 * s, weight: .black))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, 4 * s)
        }
        .frame(width: 36 * s, height: 36 * s)
        .overlay(alignment: .bottomTrailing) {
            modeBadge(scale: s)
                .offset(x: 6 * s, y: 6 * s)
        }
    }

    /// Small circular pip anchored at the bottom-right of the line
    /// badge that shows the mode the ticket is for — subway
    /// (`tram.tunnel.fill`), tram (`tram.fill`), bus (`bus.fill`),
    /// etc. Hidden when the payload predates the `mode` field.
    @ViewBuilder
    private func modeBadge(scale s: CGFloat) -> some View {
        if let symbol = modeSymbol {
            ZStack {
                Circle()
                    .fill(Color(hex: "15151F"))
                    .overlay(Circle().stroke(lineAccent, lineWidth: 1.2 * s))
                Image(systemName: symbol)
                    .font(.system(size: 9 * s, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 18 * s, height: 18 * s)
        }
    }

    private var modeSymbol: String? {
        guard let modeRaw = ticket.mode,
              let mode = TransitMode(rawValue: modeRaw) else { return nil }
        return mode.symbol
    }

    // MARK: - Journey hero

    private func journeyBlock(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            stationLine(
                label: "FROM",
                value: ticket.originStation,
                scale: s
            )

            Spacer().frame(height: 42 * s)

            stationLine(
                label: "TO",
                value: ticket.destinationStation,
                scale: s
            )
        }
    }

    private func stationLine(
        label: String,
        value: String,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4 * s) {
            Text(label)
                .font(.system(size: 7 * s, weight: .light))
                .tracking(1.75 * s)
                .foregroundStyle(.white.opacity(0.4))

            Text(value)
                .font(.system(size: 30 * s, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    // MARK: - Stops rail

    private func stopsRail(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(lineAccent)
                .frame(width: 8 * s, height: 8 * s)

            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 1, height: 34 * s)

            Text(stopsLabel)
                .font(.system(size: 7 * s, weight: .light))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .padding(.vertical, 2 * s)

            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 1, height: 34 * s)

            Circle()
                .fill(lineAccent)
                .frame(width: 8 * s, height: 8 * s)
        }
        .frame(width: 25 * s)
    }

    private var stopsLabel: String {
        ticket.stopsCount == 1
            ? String(localized: "1 stop")
            : String(localized: "\(ticket.stopsCount) stops")
    }

    // MARK: - Right aside

    private func detailsAside(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            asideRow(label: "TICKET", value: ticket.ticketNumber, scale: s)
            Spacer(minLength: 0)
            asideRow(label: "ZONES",  value: ticket.zones,        scale: s)
            Spacer(minLength: 0)
            asideRow(label: "FARE",   value: ticket.fare,         scale: s)
        }
        .padding(.leading, 17 * s)
        .padding(.trailing, 16 * s)
        .padding(.vertical, 16 * s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1)
        }
    }

    private func asideRow(
        label: String,
        value: String,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 3 * s) {
            Text(label)
                .font(.system(size: 6 * s, weight: .regular))
                .tracking(1.32 * s)
                .foregroundStyle(.white.opacity(0.75))

            Text(value)
                .font(.system(size: 12 * s, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Derived

    private var lineAccent: Color {
        Color(hex: ticket.lineColor)
    }
}

// MARK: - Preview

#Preview("Wiener Linien · U1 (subway)") {
    UndergroundTicketView(
        ticket: UndergroundTicket(
            lineShortName: "U1",
            lineName: "U1 Leopoldau – Reumannplatz",
            companyName: "Wiener Linien",
            lineColor: "#E4002B",
            originStation: "Stephansplatz",
            destinationStation: "Karlsplatz",
            stopsCount: 1,
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

#Preview("Wiener Linien · 1 (tram)") {
    UndergroundTicketView(
        ticket: UndergroundTicket(
            lineShortName: "1",
            lineName: "1 Stefan-Fadinger-Platz – Prater Hauptallee",
            companyName: "Wiener Linien",
            lineColor: "#C00808",
            originStation: "Schwedenplatz",
            destinationStation: "Praterstern",
            stopsCount: 3,
            date: "16 Jul 2026",
            ticketNumber: "123456",
            zones: "All zones",
            fare: "2.50 €",
            mode: 0
        )
    )
    .padding(24)
    .background(Color.Background.elevated)
}

#Preview("Wiener Linien · 13A (bus)") {
    UndergroundTicketView(
        ticket: UndergroundTicket(
            lineShortName: "13A",
            lineName: "13A Alser Straße – Hauptbahnhof",
            companyName: "Wiener Linien",
            lineColor: "#0A295D",
            originStation: "Alser Straße",
            destinationStation: "Hauptbahnhof",
            stopsCount: 12,
            date: "17 Jul 2026",
            ticketNumber: "654321",
            zones: "All zones",
            fare: "2.50 €",
            mode: 3
        )
    )
    .padding(24)
    .background(Color.Background.elevated)
}
