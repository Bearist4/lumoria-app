//
//  InfoscreenTicketView.swift
//  Lumoria App
//
//  Horizontal public-transport ticket — "infoscreen" style. Dark
//  card with a brushed-chrome top bar carrying a blue route-number
//  pill, company name, white Made-with-Lumoria pill and a compact
//  stops pill. A large amber-on-black destination blade beneath
//  the header (with scan-line darkening and a subtle top shine)
//  is the hero, showing the arrival station in display-weight
//  text and the origin on a smaller VIA line. A bottom meta row
//  carries TICKET / DATE / ZONE / FARE.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=266-2477
//

import SwiftUI

struct InfoscreenTicketView: View {
    let ticket: UndergroundTicket

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .topLeading) {
                darkBg

                // Chrome top bar.
                chromeBar
                    .frame(height: 44 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .top
                    )

                // Route-number pill at (20, 8).
                routePill(scale: s)
                    .padding(.leading, 20 * s)
                    .padding(.top, 8 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Company at (81, 16).
                Text(ticket.companyName)
                    .font(.system(size: 9 * s, weight: .medium))
                    .tracking(1.35 * s)
                    .foregroundStyle(subdued.opacity(0.55))
                    .lineLimit(1)
                    .padding(.leading, 81 * s)
                    .padding(.top, 16 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Made-with at (213, 10).
                if showsLumoriaWatermark {
                    MadeWithLumoria(style: .white, version: .small, scale: s)
                        .padding(.leading, 213 * s)
                        .padding(.top, 10 * s)
                        .frame(
                            maxWidth: .infinity, maxHeight: .infinity,
                            alignment: .topLeading
                        )
                }

                // Stops pill at (351, 12), 88×20.
                stopsPill(scale: s)
                    .padding(.trailing, 16 * s)
                    .padding(.top, 12 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topTrailing
                    )

                // Blade (16, 66) 423×128.
                blade(scale: s)
                    .frame(width: 423 * s, height: 128 * s)
                    .padding(.leading, 16 * s)
                    .padding(.top, 66 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // DESTINATION overline at (40, 80).
                Text("DESTINATION")
                    .font(.system(size: 8 * s, weight: .bold))
                    .tracking(2.8 * s)
                    .foregroundStyle(amber.opacity(0.55))
                    .padding(.leading, 40 * s)
                    .padding(.top, 80 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Arrival station (hero) at (40, 98), 375×42.
                Text(ticket.destinationStation)
                    .font(.system(size: 34 * s, weight: .black))
                    .tracking(1.36 * s)
                    .foregroundStyle(amber)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 375 * s, alignment: .leading)
                    .padding(.leading, 40 * s)
                    .padding(.top, 98 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // VIA label at (40, 152).
                Text("VIA")
                    .font(.system(size: 8 * s, weight: .bold))
                    .tracking(2.8 * s)
                    .foregroundStyle(amber.opacity(0.55))
                    .padding(.leading, 40 * s)
                    .padding(.top, 152 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Depart station at (66, 150), 320×18.
                Text(ticket.originStation)
                    .font(.system(size: 14 * s, weight: .heavy))
                    .tracking(0.28 * s)
                    .foregroundStyle(amber.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 320 * s, alignment: .leading)
                    .padding(.leading, 66 * s)
                    .padding(.top, 150 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // VCR scan lines — overlay ON TOP of the destination
                // and VIA text so the amber letters read through a
                // CRT / rollsign raster rather than as flat type.
                scanLines(scale: s)
                    .frame(width: 423 * s, height: 128 * s)
                    .clipShape(RoundedRectangle(cornerRadius: 10 * s, style: .continuous))
                    .allowsHitTesting(false)
                    .padding(.leading, 16 * s)
                    .padding(.top, 66 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Bottom meta row with top border at y=210.
                bottomRow(scale: s)
                    .padding(.top, 210 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .top
                    )
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 32 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Pieces

    private var darkBg: some View {
        Color(red: 0.07, green: 0.07, blue: 0.08)
    }

    private var chromeBar: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.16, green: 0.17, blue: 0.20), location: 0),
                .init(color: Color(red: 0.24, green: 0.25, blue: 0.29), location: 0.5),
                .init(color: Color(red: 0.12, green: 0.13, blue: 0.15), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func routePill(scale s: CGFloat) -> some View {
        Text(ticket.lineShortName)
            .font(.system(size: 16 * s, weight: .black))
            .tracking(0.64 * s)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 16 * s)
            .frame(height: 27 * s)
            .background(
                RoundedRectangle(cornerRadius: 40 * s, style: .continuous)
                    .fill(routeBlue)
            )
    }

    private func stopsPill(scale s: CGFloat) -> some View {
        Text(stopsLabel)
            .font(.system(size: 10 * s, weight: .bold))
            .tracking(1.2 * s)
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 16 * s)
            .frame(height: 20 * s)
            .background(
                RoundedRectangle(cornerRadius: 56 * s, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
    }

    private var stopsLabel: String {
        ticket.stopsCount == 1
            ? String(localized: "1 STOP")
            : String(localized: "\(ticket.stopsCount) STOPS")
    }

    private func blade(scale s: CGFloat) -> some View {
        ZStack {
            // Blade body.
            RoundedRectangle(cornerRadius: 10 * s, style: .continuous)
                .fill(bladeDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 10 * s, style: .continuous)
                        .stroke(subdued.opacity(0.08), lineWidth: 1)
                )

            // Subtle top shine.
            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.white.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 30 * s)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .mask(
                RoundedRectangle(cornerRadius: 10 * s, style: .continuous)
            )
        }
    }

    private func scanLines(scale s: CGFloat) -> some View {
        Canvas { context, size in
            let step: CGFloat = 3 * s
            let thickness: CGFloat = max(1 * s, 0.5)
            let lineColor = GraphicsContext.Shading.color(
                red: 0.07, green: 0.07, blue: 0.08, opacity: 0.15
            )
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: thickness)
                context.fill(Path(rect), with: lineColor)
                y += step
            }
        }
    }

    private func bottomRow(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(subdued.opacity(0.1))
                .frame(height: 1)

            HStack(alignment: .top, spacing: 16 * s) {
                metaCell(label: "TICKET",
                         value: ticket.ticketNumber,
                         scale: s)
                    .frame(maxWidth: .infinity, alignment: .leading)

                metaCell(label: "DATE",
                         value: ticket.date,
                         scale: s)
                    .frame(width: 72 * s, alignment: .leading)

                metaCell(label: "ZONE",
                         value: ticket.zones,
                         scale: s)
                    .frame(width: 60 * s, alignment: .leading)

                metaCell(label: "FARE",
                         value: ticket.fare,
                         valueColor: amber,
                         scale: s)
                    .frame(width: 60 * s, alignment: .leading)
            }
            .padding(.horizontal, 16 * s)
            .padding(.top, 8 * s)
            .padding(.bottom, 16 * s)
        }
    }

    private func metaCell(
        label: String,
        value: String,
        valueColor: Color = .white,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 8 * s, weight: .medium))
                .tracking(1.76 * s)
                .foregroundStyle(subdued.opacity(0.45))
            Text(value)
                .font(.system(size: 13 * s, weight: .bold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    // MARK: - Colors

    private var amber: Color { Color(red: 1, green: 0.72, blue: 0.14) }
    private var routeBlue: Color { Color(red: 0.16, green: 0.47, blue: 0.92) }
    private var bladeDark: Color { Color(red: 0.04, green: 0.04, blue: 0.05) }
    private var subdued: Color { Color(red: 0.86, green: 0.86, blue: 0.88) }
}

#Preview("Infoscreen · 74 (bus)") {
    InfoscreenTicketView(
        ticket: UndergroundTicket(
            lineShortName: "74",
            lineName: "Line 74 — Alser Straße ↔ Hauptbahnhof",
            companyName: "Wiener Linien",
            lineColor: "#0A295D",
            originStation: "Alser Straße",
            destinationStation: "Hauptbahnhof",
            stopsCount: 12,
            date: "08:42",
            ticketNumber: "654321",
            zones: "1–2",
            fare: "1.50€",
            mode: 3
        )
    )
    .padding(24)
    .background(Color.Background.elevated)
}
