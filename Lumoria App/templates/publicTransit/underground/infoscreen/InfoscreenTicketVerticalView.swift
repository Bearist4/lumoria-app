//
//  InfoscreenTicketVerticalView.swift
//  Lumoria App
//
//  Vertical public-transport ticket — "infoscreen" style. Dark
//  card with a brushed-chrome top bar (blue route-number pill
//  and company label), a white Made-with-Lumoria pill + compact
//  stops pill stacked below the header, a tall amber-on-black
//  destination blade that fills most of the body, and a 2×2
//  meta grid at the bottom (TICKET / DATE on top, ZONE / FARE
//  on bottom — FARE accented amber).
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=266-2476
//

import SwiftUI

struct InfoscreenTicketVerticalView: View {
    let ticket: UndergroundTicket

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack(alignment: .topLeading) {
                darkBg

                chromeBar
                    .frame(height: 44 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .top
                    )

                // Route pill (20, 8).
                routePill(scale: s)
                    .padding(.leading, 20 * s)
                    .padding(.top, 8 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Made-with pill (16, 52).
                if showsLumoriaWatermark {
                    MadeWithLumoria(style: .white, version: .small, scale: s)
                        .padding(.leading, 16 * s)
                        .padding(.top, 52 * s)
                        .frame(
                            maxWidth: .infinity, maxHeight: .infinity,
                            alignment: .topLeading
                        )
                }

                // Stops pill right of made-with.
                stopsPill(scale: s)
                    .padding(.trailing, 16 * s)
                    .padding(.top, 52 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topTrailing
                    )

                // Blade (16, 84) 228×261.
                blade(scale: s)
                    .frame(width: 228 * s, height: 261 * s)
                    .padding(.leading, 16 * s)
                    .padding(.top, 84 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // DESTINATION label (29, 160).
                Text("DESTINATION")
                    .font(.system(size: 8 * s, weight: .bold))
                    .tracking(2.8 * s)
                    .foregroundStyle(amber.opacity(0.55))
                    .padding(.leading, 29 * s)
                    .padding(.top, 160 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Arrival (hero) (29, 178), 197 wide, 23pt.
                Text(ticket.destinationStation)
                    .font(.system(size: 23 * s, weight: .black))
                    .tracking(0.92 * s)
                    .foregroundStyle(amber)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .frame(width: 197 * s, alignment: .leading)
                    .padding(.leading, 29 * s)
                    .padding(.top, 178 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // VIA label (29, 234).
                Text("VIA")
                    .font(.system(size: 8 * s, weight: .bold))
                    .tracking(2.8 * s)
                    .foregroundStyle(amber.opacity(0.55))
                    .padding(.leading, 29 * s)
                    .padding(.top, 234 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Depart station (29, 252), 197 wide, 14pt.
                Text(ticket.originStation)
                    .font(.system(size: 14 * s, weight: .heavy))
                    .tracking(0.28 * s)
                    .foregroundStyle(amber.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 197 * s, alignment: .leading)
                    .padding(.leading, 29 * s)
                    .padding(.top, 252 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // VCR scan lines — overlay ON TOP of the destination
                // and VIA text so the amber letters read through a
                // CRT / rollsign raster rather than as flat type.
                scanLines(scale: s)
                    .frame(width: 228 * s, height: 261 * s)
                    .clipShape(RoundedRectangle(cornerRadius: 10 * s, style: .continuous))
                    .allowsHitTesting(false)
                    .padding(.leading, 16 * s)
                    .padding(.top, 84 * s)
                    .frame(
                        maxWidth: .infinity, maxHeight: .infinity,
                        alignment: .topLeading
                    )

                // Bottom meta grid at y=371 (full width, height 84).
                metaGrid(scale: s)
                    .padding(.top, 371 * s)
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
                    .fill(lineAccent)
            )
    }

    private func stopsPill(scale s: CGFloat) -> some View {
        Text(stopsLabel)
            .font(.system(size: 10 * s, weight: .bold))
            .tracking(1.2 * s)
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 16 * s)
            .frame(height: 24 * s)
            .background(
                RoundedRectangle(cornerRadius: 56 * s, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
    }

    private var stopsLabel: String {
        ticket.stopsCount == 1
            ? String(localized: "1 STOP", locale: .ticket)
            : String(localized: "\(ticket.stopsCount) STOPS", locale: .ticket)
    }

    private func blade(scale s: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10 * s, style: .continuous)
                .fill(bladeDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 10 * s, style: .continuous)
                        .stroke(subdued.opacity(0.08), lineWidth: 1)
                )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.white.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28 * s)
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

    private func metaGrid(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(subdued.opacity(0.1))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8 * s) {
                HStack(alignment: .top, spacing: 8 * s) {
                    metaCell(label: "Ticket",
                             value: ticket.ticketNumber,
                             scale: s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metaCell(label: "Date",
                             value: ticket.date,
                             scale: s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(alignment: .top, spacing: 8 * s) {
                    metaCell(label: "Zone",
                             value: ticket.zones,
                             scale: s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metaCell(label: "Fare",
                             value: ticket.fare,
                             valueColor: amber,
                             scale: s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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
    private var lineAccent: Color { Color(hex: ticket.lineColor) }
    private var bladeDark: Color { Color(red: 0.04, green: 0.04, blue: 0.05) }
    private var subdued: Color { Color(red: 0.86, green: 0.86, blue: 0.88) }
}

#Preview("Infoscreen · 74 (bus)") {
    InfoscreenTicketVerticalView(
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
