//
//  SignalTicketView.swift
//  Lumoria App
//
//  Horizontal public-transport ticket — "signal" style. A dark
//  455×260 card with a full-height line-colored spine on the left,
//  a soft radial bloom keyed to the line color, a rounded-square
//  line bullet in the top-left, a mode pill ("SUBWAY", "TRAM",
//  "BUS"), a compact stops pill top-right, FROM/TO hero stations
//  stacked across the middle, and a TICKET/ZONE/FARE meta row
//  along the bottom above a hairline rule.
//
//  Every overlay uses `.frame(maxWidth: .infinity, maxHeight:
//  .infinity, alignment:)` plus `.padding(.leading/.trailing/.top)`
//  so content is absolutely positioned against the Figma frame.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=260-2120
//

import SwiftUI

struct SignalTicketView: View {
    let ticket: UndergroundTicket

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260
    private let cardColor = Color(hex: "0B0C13")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .topLeading) {
                cardColor

                // Line-color bloom — 300×300 ellipse, blurred.
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

                // Full-height spine.
                Rectangle()
                    .fill(lineAccent)
                    .frame(width: 14 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .leading
                    )

                // Line bullet.
                lineBullet(scale: s)
                    .padding(.leading, 30 * s)
                    .padding(.top, 28 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Mode pill.
                modePill(scale: s)
                    .padding(.leading, 98 * s)
                    .padding(.top, 28 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Operator label.
                Text(ticket.companyName)
                    .font(.system(size: 10 * s, weight: .medium))
                    .tracking(1 * s)
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .padding(.leading, 98 * s)
                    .padding(.top, 56 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Made-with pill.
                if showsLumoriaWatermark {
                    MadeWithLumoria(style: .white, version: .small, scale: s)
                        .padding(.leading, 218 * s)
                        .padding(.top, 28 * s)
                        .frame(
                            maxWidth: .infinity, maxHeight: .infinity,
                            alignment: .topLeading
                        )
                }

                // Stops pill.
                stopsPill(scale: s)
                    .padding(.trailing, 24 * s)
                    .padding(.top, 24 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topTrailing
                    )

                // FROM overline.
                Text("FROM")
                    .font(.system(size: 8 * s, weight: .light))
                    .tracking(2.4 * s)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.leading, 30 * s)
                    .padding(.top, 116 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Depart station.
                Text(ticket.originStation)
                    .font(.system(size: 22 * s, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 190 * s, alignment: .leading)
                    .padding(.leading, 30 * s)
                    .padding(.top, 128 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // TO overline.
                Text("TO")
                    .font(.system(size: 8 * s, weight: .light))
                    .tracking(2.4 * s)
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 120 * s, alignment: .trailing)
                    .padding(.trailing, 24 * s)
                    .padding(.top, 116 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topTrailing
                    )

                // Arrival station.
                Text(ticket.destinationStation)
                    .font(.system(size: 22 * s, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: 200 * s, alignment: .trailing)
                    .padding(.trailing, 24 * s)
                    .padding(.top, 128 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topTrailing
                    )

                // Bottom meta row.
                bottomMeta(scale: s)
                    .frame(height: 62 * s)
                    .padding(.leading, 14 * s)
                    .padding(.top, 198 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
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

    /// Ramps the bullet type size down as the line short-name
    /// grows so "U1" hits the hero 26pt but "RER A" still fits
    /// without relying on `minimumScaleFactor` alone.
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

    private func stopsPill(scale s: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 8 * s) {
            Text("\(ticket.stopsCount)")
                .font(.system(size: 16 * s, weight: .black, design: .rounded))
                .foregroundStyle(lineAccent)

            Text("STOPS")
                .font(.system(size: 9 * s, weight: .bold))
                .tracking(1.8 * s)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 4 * s)
        }
        .padding(.horizontal, 12 * s)
        .padding(.vertical, 8 * s)
        .background(
            RoundedRectangle(cornerRadius: 8 * s, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func bottomMeta(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)

            HStack(alignment: .top, spacing: 0) {
                metaCell(label: "TICKET", value: ticket.ticketNumber, scale: s)
                metaCell(label: "ZONE",   value: ticket.zones,        scale: s)
                metaCell(label: "FARE",   value: ticket.fare,         scale: s)
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

    // MARK: - Derived

    private var lineAccent: Color {
        Color(hex: ticket.lineColor)
    }

    private var modeWordmark: String {
        guard let raw = ticket.mode,
              let mode = TransitMode(rawValue: raw)
        else {
            return "TRANSIT"
        }
        switch mode {
        case .subway:                 return "SUBWAY"
        case .tram, .cableTram:       return "TRAM"
        case .bus, .trolleybus:       return "BUS"
        case .rail:                   return "TRAIN"
        case .ferry:                  return "FERRY"
        case .aerialLift, .funicular: return "CABLE"
        case .monorail:               return "MONORAIL"
        }
    }
}

#Preview("Signal · U1") {
    SignalTicketView(
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
