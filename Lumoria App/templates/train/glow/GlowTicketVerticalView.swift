//
//  GlowTicketVerticalView.swift
//  Lumoria App
//
//  Vertical "Glow" train ticket — pitch-black card with the same warm
//  orange / magenta bloom, split into a tall main section (top) and a
//  shorter stub (bottom) by a horizontal dashed perforation + punch.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=158-12798
//

import SwiftUI

struct GlowTicketVerticalView: View {
    let ticket: GlowTicket
    var style: TicketStyleVariant = TicketTemplateKind.glow.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455
    /// Fraction of height consumed by the bottom stub (124px of 455px
    /// in the figma = ~0.272).
    private let stubFraction: CGFloat = 124.0 / 455.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260
            let mainH = h * (1 - stubFraction)
            let stubH = h * stubFraction

            ZStack(alignment: .topLeading) {
                glowBackdrop(w: w, h: h)

                VStack(spacing: 0) {
                    mainSection(scale: s)
                        .frame(width: w, height: mainH)

                    stubSection(scale: s)
                        .frame(width: w, height: stubH)
                }
                .frame(width: w, height: h)

                perforation(scale: s, y: mainH, width: w)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 24 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Backdrop

    /// Full-bleed artwork: `glow-gradient-vertical` clipped to the
    /// `glow-bg-vertical` silhouette mask. Mirrors the horizontal
    /// variant with orientation-specific assets.
    @ViewBuilder
    private func glowBackdrop(w: CGFloat, h: CGFloat) -> some View {
        let bgMask = Image("glow-bg-vertical").resizable().frame(width: w, height: h)

        ZStack {
            Color.black
                .frame(width: w, height: h)
                .mask(bgMask)

            Image("glow-gradient-vertical")
                .resizable()
                .frame(width: w, height: h)
                .mask(bgMask)
        }
    }

    // MARK: - Main section

    private func mainSection(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow(scale: s)
                .padding(.horizontal, 24 * s)
                .padding(.vertical, 16 * s)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)

            journeyRows(scale: s)
                .padding(.horizontal, 24 * s)
                .padding(.top, 24 * s)
                .padding(.bottom, 24 * s)
                .frame(maxHeight: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)

            detailsGrid(scale: s)
                .padding(.horizontal, 24 * s)
                .padding(.vertical, 16 * s)
                .frame(height: 96 * s)
        }
    }

    private func headerRow(scale s: CGFloat) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3 * s) {
                Text(ticket.trainNumber.uppercased())
                    .font(.system(size: 6 * s, weight: .bold))
                    .tracking(1.41 * s)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .lineLimit(1)
                Text(ticket.trainType)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(0.47 * s)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()

            if showsLumoriaWatermark {
                MadeWithLumoria(style: .white, version: .small, scale: s)
            }
        }
    }

    private func journeyRows(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            cityBlock(
                label: "From",
                city: ticket.originCity,
                station: ticket.originStation,
                alignment: .leading,
                scale: s
            )
            .frame(maxHeight: .infinity)

            cityBlock(
                label: "To",
                city: ticket.destinationCity,
                station: ticket.destinationStation,
                alignment: .trailing,
                scale: s
            )
            .frame(maxHeight: .infinity)
        }
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
                .font(.system(size: 6.3 * s, weight: .regular))
                .tracking(0.88 * s)
                .foregroundStyle(Color.white.opacity(0.5))

            Text(city)
                .font(.system(size: 25 * s, weight: .bold))
                .tracking(-0.5 * s)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(station.uppercased())
                .font(.system(size: 6.3 * s, weight: .regular))
                .tracking(0.88 * s)
                .foregroundStyle(Color.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    // MARK: - Details grid (2×2 in main) — Date / Depart / Car / Seat

    private func detailsGrid(scale s: CGFloat) -> some View {
        VStack(spacing: 8 * s) {
            HStack(spacing: 8 * s) {
                detailCell(label: "Date",   value: ticket.date,          alignment: .leading,  scale: s)
                detailCell(label: "Depart", value: ticket.departureTime, alignment: .trailing, scale: s)
            }
            HStack(spacing: 8 * s) {
                detailCell(label: "Car",    value: ticket.car,           alignment: .leading,  scale: s)
                detailCell(label: "Seat",   value: ticket.seat,          alignment: .trailing, scale: s)
            }
        }
    }

    private func detailCell(
        label: String,
        value: String,
        alignment: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: alignment, spacing: 3 * s) {
            Text(label.uppercased())
                .font(.system(size: 6 * s, weight: .regular))
                .tracking(1.32 * s)
                .foregroundStyle(Color.white.opacity(0.75))
            Text(value)
                .font(.system(size: 12 * s, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    // MARK: - Stub (bottom section)

    private func stubSection(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12 * s) {
            // Route line — Origin → Destination with arrow glyph
            HStack(alignment: .center) {
                Text(ticket.originCity)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(-0.5 * s)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.system(size: 8 * s, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.75))

                Text(ticket.destinationCity)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(-0.5 * s)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Duplicated Date / Depart / Car / Seat 2x2
            VStack(spacing: 8 * s) {
                HStack(spacing: 8 * s) {
                    stubCell(label: "Date",   value: ticket.date,          alignment: .leading,  scale: s)
                    stubCell(label: "Depart", value: ticket.departureTime, alignment: .trailing, scale: s)
                }
                HStack(spacing: 8 * s) {
                    stubCell(label: "Car",    value: ticket.car,           alignment: .leading,  scale: s)
                    stubCell(label: "Seat",   value: ticket.seat,          alignment: .trailing, scale: s)
                }
            }
        }
        .padding(.horizontal, 24 * s)
        .padding(.top, 20 * s)
        .padding(.bottom, 16 * s)
    }

    private func stubCell(
        label: String,
        value: String,
        alignment: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: alignment, spacing: 3 * s) {
            Text(label.uppercased())
                .font(.system(size: 6 * s, weight: .regular))
                .tracking(1.32 * s)
                .foregroundStyle(Color.white.opacity(0.75))
            Text(value)
                .font(.system(size: 12 * s, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    // MARK: - Perforation + punch (horizontal)

    private func perforation(scale s: CGFloat, y: CGFloat, width w: CGFloat) -> some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: w, y: y))
            }
            .stroke(
                Color.white.opacity(0.4),
                style: StrokeStyle(
                    lineWidth: 1,
                    dash: [2 * s, 3 * s]
                )
            )

            Circle()
                .fill(Color.white)
                .frame(width: 32 * s, height: 32 * s)
                .position(x: w / 2, y: y)
        }
        .frame(width: w, height: 0, alignment: .topLeading)
    }
}

// MARK: - Preview

#Preview("Glow — vertical") {
    GlowTicketVerticalView(ticket: GlowTicket(
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
