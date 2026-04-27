//
//  SignalTicketVerticalView.swift
//  Lumoria App
//
//  Vertical public-transport ticket — "signal" style. A 260×450
//  dark card that mirrors the horizontal variant's brand language:
//  line-color spine along the top edge, line-color bloom in the
//  top-left, rounded-square line bullet + mode pill + operator at
//  the top, FROM station below, a stops-count pill in the centre
//  flanked by vertical connector lines, TO station aligned to the
//  right above a ZONE/FARE/TICKET grid, and a full-width
//  Made-with-Lumoria strip along the bottom edge.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=260-2119
//

import SwiftUI

struct SignalTicketVerticalView: View {
    let ticket: UndergroundTicket

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 450
    private let cardColor = Color(hex: "0B0C13")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack(alignment: .topLeading) {
                cardColor

                Circle()
                    .fill(lineAccent.opacity(0.18))
                    .frame(width: 300 * s, height: 300 * s)
                    .blur(radius: 60 * s)
                    .padding(.leading, -60 * s)
                    .padding(.top, -170 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                Rectangle()
                    .fill(lineAccent)
                    .frame(height: 14 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .top
                    )

                lineBullet(scale: s)
                    .padding(.leading, 16 * s)
                    .padding(.top, 30 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                modePill(scale: s)
                    .padding(.leading, 84 * s)
                    .padding(.top, 30 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                Text(ticket.companyName)
                    .font(.system(size: 10 * s, weight: .medium))
                    .tracking(1 * s)
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .padding(.leading, 84 * s)
                    .padding(.top, 58 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                Text("FROM")
                    .font(.system(size: 8 * s, weight: .light))
                    .tracking(2.4 * s)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.leading, 16 * s)
                    .padding(.top, 118 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                Text(ticket.originStation)
                    .font(.system(size: heroStationFont * s, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 190 * s, alignment: .leading)
                    .padding(.leading, 16 * s)
                    .padding(.top, 130 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                stopsCluster(scale: s)
                    .padding(.top, 164 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .top
                    )

                Text("TO")
                    .font(.system(size: 8 * s, weight: .light))
                    .tracking(2.4 * s)
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 120 * s, alignment: .trailing)
                    .padding(.trailing, 16 * s)
                    .padding(.top, 248 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topTrailing
                    )

                Text(ticket.destinationStation)
                    .font(.system(size: heroStationFont * s, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: 228 * s, alignment: .trailing)
                    .padding(.trailing, 16 * s)
                    .padding(.top, 260 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topTrailing
                    )

                metaGrid(scale: s)
                    .frame(height: 100 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )
                    .padding(.top, 310 * s)

                madeWithStrip(scale: s)
                    .frame(height: 40 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .bottomLeading
                    )
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 32 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Pieces

    private func lineBullet(scale s: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12 * s, style: .continuous)
                .fill(lineAccent)
                .overlay(
                    RoundedRectangle(cornerRadius: 12 * s, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            Text(ticket.lineShortName)
                .font(.system(size: bulletFontSize * s, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, 4 * s)
        }
        .frame(width: 56 * s, height: 56 * s)
    }

    /// Shared FROM / TO font size — same idea as SignalTicketView.
    private var heroStationFont: CGFloat {
        transitStationFontSize(
            origin: ticket.originStation,
            destination: ticket.destinationStation
        )
    }

    private var bulletFontSize: CGFloat {
        switch ticket.lineShortName.count {
        case 0...2: return 26
        case 3:     return 20
        case 4:     return 16
        default:    return 13
        }
    }

    private func modePill(scale s: CGFloat) -> some View {
        Text(modeWordmark)
            .font(.system(size: 10 * s, weight: .black))
            .tracking(2.5 * s)
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 12 * s)
            .padding(.vertical, 4 * s)
            .background(
                RoundedRectangle(cornerRadius: 6 * s, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
    }

    private func stopsCluster(scale s: CGFloat) -> some View {
        VStack(spacing: 4 * s) {
            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 1, height: 19 * s)

            stopsPill(scale: s)

            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 1, height: 19 * s)
        }
    }

    private func stopsPill(scale s: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 8 * s) {
            Text("\(ticket.stopsCount)")
                .font(.system(size: 16 * s, weight: .black, design: .rounded))
                .foregroundStyle(lineAccent)

            Text("STOPS")
                .font(.system(size: 9 * s, weight: .bold))
                .tracking(1.8 * s)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize()
        }
        .padding(.horizontal, 12 * s)
        .padding(.vertical, 8 * s)
        .background(
            RoundedRectangle(cornerRadius: 8 * s, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func metaGrid(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8 * s) {
                HStack(alignment: .top, spacing: 8 * s) {
                    metaCell(label: "ZONE", value: ticket.zones, scale: s)
                    metaCell(label: "FARE", value: ticket.fare,  scale: s)
                }
                HStack(alignment: .top, spacing: 8 * s) {
                    metaCell(label: "TICKET", value: ticket.ticketNumber, scale: s)
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
            .padding(16 * s)
        }
    }

    private func metaCell(label: String, value: String, scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4 * s) {
            Text(label)
                .font(.system(size: 8 * s, weight: .medium))
                .tracking(1.6 * s)
                .foregroundStyle(.white.opacity(0.45))

            Text(value)
                .font(.system(size: 13 * s, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func madeWithStrip(scale s: CGFloat) -> some View {
        ZStack {
            Color.white
            if showsLumoriaWatermark {
                MadeWithLumoria(
                    style: .white,
                    version: .full,
                    scale: s,
                    fullWidth: true
                )
            }
        }
    }

    // MARK: - Derived

    private var lineAccent: Color {
        Color(hex: ticket.lineColor)
    }

    private var modeWordmark: String {
        guard let raw = ticket.mode,
              let mode = TransitMode(rawValue: raw)
        else {
            return String(localized: "TRANSIT")
        }
        switch mode {
        case .subway:                 return String(localized: "SUBWAY")
        case .tram, .cableTram:       return String(localized: "TRAM")
        case .bus, .trolleybus:       return String(localized: "BUS")
        case .rail:                   return String(localized: "TRAIN")
        case .ferry:                  return String(localized: "FERRY")
        case .aerialLift, .funicular: return String(localized: "CABLE")
        case .monorail:               return String(localized: "MONORAIL")
        }
    }
}

#Preview("Signal · U1") {
    SignalTicketVerticalView(
        ticket: UndergroundTicket(
            lineShortName: "U1",
            lineName: "U1 Leopoldau – Reumannplatz",
            companyName: "Wiener Linien",
            lineColor: "#E4002B",
            originStation: "Stephansplatz",
            destinationStation: "Karlsplatz",
            stopsCount: 7,
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
