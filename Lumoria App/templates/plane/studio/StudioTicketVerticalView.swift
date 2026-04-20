//
//  StudioTicketVerticalView.swift
//  Lumoria App
//
//  Vertical boarding-pass card for the "Studio" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=1-1557
//

import SwiftUI

struct StudioTicketVerticalView: View {
    let ticket: StudioTicket
    var style: TicketStyleVariant = TicketTemplateKind.studio.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455
    private let cornerRadius: CGFloat = 32

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack(alignment: .bottom) {
                // Rotated ticket shape (original is 455x260, rotated 90° cw → 260x455).
                if let asset = style.backgroundAsset {
                    Image(asset)
                        .resizable()
                        .frame(width: h, height: w)
                        .rotationEffect(.degrees(90))
                        .frame(width: w, height: h)
                }

                // Main content column.
                VStack(spacing: 0) {
                    headerSection(scale: s)

                    Spacer(minLength: 0)
                    divider
                    Spacer(minLength: 0)

                    routeSection(scale: s)
                        .frame(height: 231 * s)

                    Spacer(minLength: 0)
                    divider
                    Spacer(minLength: 0)

                    detailsSection(scale: s)
                        .frame(height: 32 * s)
                }
                .padding(.horizontal, 24 * s)
                .padding(.top, 36 * s)
                .padding(.bottom, 48 * s)
                .frame(width: w, height: h)

                // Footer "Made with Lumoria" strip — the strip is full
                // ticket-sized but masked by the ticket silhouette so
                // the strip conforms to every notch/corner in the art.
                if let asset = style.backgroundAsset {
                    ZStack(alignment: .bottom) {
                        Color.clear
                        madeWithStrip(scale: s)
                            .frame(height: 40 * s)
                    }
                    .frame(width: w, height: h)
                    .mask {
                        Image(asset)
                            .resizable()
                            .frame(width: h, height: w)
                            .rotationEffect(.degrees(90))
                            .frame(width: w, height: h)
                    }
                }
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Header

    private func headerSection(scale s: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 4 * s) {
            HStack {
                Text(ticket.airline.uppercased())
                    .font(.system(size: 8 * s, weight: .bold))
                    .foregroundStyle(style.textSecondary)

                Spacer()

                Text(ticket.cabinClass)
                    .font(.system(size: 8 * s, weight: .bold))
                    .foregroundStyle(style.onAccent)
                    .padding(.horizontal, 8 * s)
                    .padding(.vertical, 4 * s)
                    .background(
                        RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
                            .fill(style.accent)
                    )
            }

            HStack {
                Text("\(ticket.flightNumber) · Boarding Pass")
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(0.44 * s)
                    .foregroundStyle(style.textPrimary)
                    .lineLimit(1)

                Spacer()
            }
        }
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(style.divider)
            .frame(height: 1)
    }

    // MARK: - Route

    private func routeSection(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            airportBlock(
                code: ticket.origin,
                name: ticket.originName,
                location: ticket.originLocation,
                scale: s
            )

            Spacer(minLength: 0)

            Image(systemName: "airplane")
                .font(.system(size: 16 * s, weight: .regular))
                .foregroundStyle(style.accent)

            Spacer(minLength: 0)

            airportBlock(
                code: ticket.destination,
                name: ticket.destinationName,
                location: ticket.destinationLocation,
                scale: s
            )
        }
        .padding(.horizontal, 24 * s)
    }

    private func airportBlock(
        code: String,
        name: String,
        location: String,
        scale s: CGFloat
    ) -> some View {
        VStack(spacing: 4 * s) {
            Text(code)
                .font(.system(size: 48 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(name)
                .font(.system(size: 9.41 * s, weight: .bold))
                .tracking(0.38 * s)
                .foregroundStyle(style.textPrimary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            Text(location.uppercased())
                .font(.system(size: 6.28 * s, weight: .regular))
                .tracking(0.75 * s)
                .foregroundStyle(style.textSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
    }

    // MARK: - Footer details (Date / Gate / Seat / Departs)

    private func detailsSection(scale s: CGFloat) -> some View {
        // Four cells distributed evenly across the footer row. Matches
        // the Figma (node-id 1:1557) — no pill dividers, equal columns,
        // each cell left-aligned within its share of the row.
        HStack(spacing: 0) {
            detailCell(label: "Date",    value: ticket.date,          scale: s)
            detailCell(label: "Gate",    value: ticket.gate,          scale: s)
            detailCell(label: "Seat",    value: ticket.seat,          scale: s)
            detailCell(label: "Departs", value: ticket.departureTime, scale: s)
        }
    }

    private func detailCell(label: String, value: String, scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: 5.49 * s, weight: .regular))
                .tracking(1.1 * s)
                .foregroundStyle(style.textSecondary)

            Text(value)
                .font(.system(size: 10.98 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Bottom "Made with Lumoria" strip

    /// Bottom "Made with Lumoria" strip — a colored bar that's part of
    /// Studio's silhouette. The bar stays to keep layout stable; its
    /// contents are hidden when the user disables the watermark.
    @ViewBuilder
    private func madeWithStrip(scale s: CGFloat) -> some View {
        ZStack {
            style.footerFill

            if showsLumoriaWatermark {
                MadeWithLumoria(
                    style: style.footerScheme == .dark ? .black : .white,
                    version: .full,
                    scale: s,
                    fullWidth: true
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    StudioTicketVerticalView(ticket: StudioTicket(
        airline: "Airline",
        flightNumber: "FlightNumber",
        cabinClass: "Class",
        origin: "NRT",
        originName: "Narita International",
        originLocation: "Tokyo, Japan",
        destination: "JFK",
        destinationName: "John F. Kennedy",
        destinationLocation: "New York, United States",
        date: "8 Jun 2026",
        gate: "74",
        seat: "1K",
        departureTime: "11:05"
    ))
    .padding(24)
    .background(Color.Background.default)
}
