//
//  GlowTicketView.swift
//  Lumoria App
//
//  Horizontal "Glow" train ticket — pitch-black card with a warm
//  orange/magenta bloom radiating from the bottom edges, split into a
//  main section and a narrower stub by a dashed perforation + punch
//  disc. All typography in white sans-serif for maximum pop.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=158-12799
//

import SwiftUI

struct GlowTicketView: View {
    let ticket: GlowTicket
    var style: TicketStyleVariant = TicketTemplateKind.glow.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260
    /// Fraction of width consumed by the right-hand stub (123px of 455px
    /// in the figma = ~0.27).
    private let stubFraction: CGFloat = 123.0 / 455.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455
            let mainW = w * (1 - stubFraction)
            let stubW = w * stubFraction

            ZStack(alignment: .topLeading) {
                glowBackdrop(w: w, h: h)

                HStack(spacing: 0) {
                    mainSection(scale: s)
                        .frame(width: mainW, height: h)

                    stubSection(scale: s)
                        .frame(width: stubW, height: h)
                }
                .frame(width: w, height: h)

                // Dashed perforation + centre punch between the two
                // sections. Drawn on top of the text layer so the punch
                // disc sits over whatever would otherwise cross it.
                perforation(scale: s, x: mainW, height: h)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 24 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Backdrop

    /// Full-bleed artwork: `glow-gradient` clipped to the `glow-bg`
    /// silhouette mask. Matches the Prism pattern — the gradient lives
    /// in its own asset so designers can swap the bloom without
    /// touching the ticket shape.
    @ViewBuilder
    private func glowBackdrop(w: CGFloat, h: CGFloat) -> some View {
        let bgMask = Image("glow-bg").resizable().frame(width: w, height: h)

        ZStack {
            // Solid black base inside the mask — keeps the shape opaque
            // even where the gradient art is transparent so nothing
            // behind the ticket bleeds through the perforation stub.
            Color.black
                .frame(width: w, height: h)
                .mask(bgMask)

            Image("glow-gradient")
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

            // Top rule
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)

            journeyRows(scale: s)
                .padding(.leading, 24 * s)
                .padding(.trailing, 40 * s)
                .padding(.top, 20 * s)
                .padding(.bottom, 24 * s)
                .frame(maxHeight: .infinity)

            // Bottom rule
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)

            detailsRow(scale: s)
                .padding(.horizontal, 24 * s)
                .padding(.vertical, 16 * s)
                .frame(height: 62 * s)
        }
    }

    // MARK: - Header (train info + made-with pill)

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

    // MARK: - Cities

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
            Text(label).textCase(.uppercase)
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

    // MARK: - Details row

    private func detailsRow(scale s: CGFloat) -> some View {
        HStack(spacing: 0) {
            detailCell(label: "Date",   value: ticket.date,          showDivider: false, scale: s)
            detailCell(label: "Depart", value: ticket.departureTime, showDivider: true,  scale: s)
            detailCell(label: "Car",    value: ticket.car,           showDivider: true,  scale: s)
            detailCell(label: "Seat",   value: ticket.seat,          showDivider: true,  scale: s)
        }
    }

    private func detailCell(
        label: String,
        value: String,
        showDivider: Bool,
        scale s: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            if showDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 27 * s)
            }
            VStack(alignment: .leading, spacing: 3 * s) {
                Text(label).textCase(.uppercase)
                    .font(.system(size: 6 * s, weight: .regular))
                    .tracking(1.32 * s)
                    .foregroundStyle(Color.white.opacity(0.75))
                Text(value)
                    .font(.system(size: 12 * s, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, showDivider ? 9 * s : 0)
        }
    }

    // MARK: - Stub (right side)

    private func stubSection(scale s: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 8 * s) {
            // Top block — duplicated Date / Depart / Car / Seat
            VStack(alignment: .trailing, spacing: 8 * s) {
                stubCell(label: "Date",   value: ticket.date,          scale: s)
                stubCell(label: "Depart", value: ticket.departureTime, scale: s)
                stubCell(label: "Car",    value: ticket.car,           scale: s)
                stubCell(label: "Seat",   value: ticket.seat,          scale: s)
            }

            Spacer(minLength: 0)

            // Bottom block — Origin ↓ Destination
            VStack(alignment: .trailing, spacing: 4 * s) {
                Text(ticket.originCity)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(-0.5 * s)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Image(systemName: "arrow.down")
                    .font(.system(size: 8 * s, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.75))

                Text(ticket.destinationCity)
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(-0.5 * s)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .padding(16 * s)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func stubCell(
        label: String,
        value: String,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: .trailing, spacing: 3 * s) {
            Text(label).textCase(.uppercase)
                .font(.system(size: 6 * s, weight: .regular))
                .tracking(1.32 * s)
                .foregroundStyle(Color.white.opacity(0.75))
            Text(value)
                .font(.system(size: 12 * s, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    // MARK: - Perforation + punch

    /// Dashed line running top→bottom at `x`, with a white disc punched
    /// over the midpoint. Draws outside the two sections so text never
    /// runs into the seam.
    private func perforation(scale s: CGFloat, x: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: h))
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
                .position(x: x, y: h / 2)
        }
        .frame(width: 0, height: h, alignment: .topLeading)
    }
}

// MARK: - Preview

private let glowPreviewTicket = GlowTicket(
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
)

#Preview("Glow — horizontal") {
    GlowTicketView(ticket: glowPreviewTicket)
        .padding(24)
        .background(Color.Background.default)
}
