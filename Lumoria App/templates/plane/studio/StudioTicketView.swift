//
//  StudioTicketView.swift
//  Lumoria App
//
//  Horizontal boarding-pass card for the "Studio" ticket style.
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=1-1385
//

import SwiftUI

// MARK: - Model

struct StudioTicket: Codable, Hashable {
    var airline: String                 // "Airline"
    var flightNumber: String            // "FlightNumber"
    var cabinClass: String              // "Class"
    var origin: String                  // "NRT"
    var originName: String              // "Narita International"
    var originLocation: String          // "Tokyo, Japan"
    var destination: String             // "JFK"
    var destinationName: String         // "John F. Kennedy"
    var destinationLocation: String     // "New York, United States"
    var date: String                    // "8 Jun 2026"
    var gate: String                    // "74"
    var seat: String                    // "1K"
    var departureTime: String           // "11:05"
}

// MARK: - View

struct StudioTicketView: View {
    let ticket: StudioTicket
    var style: TicketStyleVariant = TicketTemplateKind.studio.defaultStyle

    @Environment(\.brandSlug) private var brandSlug

    private let aspectRatio: CGFloat = 455 / 260

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack {
                if let asset = style.backgroundAsset {
                    Image(asset)
                        .resizable()
                        .frame(width: w, height: h)
                }

                VStack(spacing: 0) {
                    headerRow(scale: s)
                        .frame(height: 32 * s)

                    Spacer(minLength: 0)
                    divider
                    Spacer(minLength: 0)

                    routeRow(scale: s)

                    Spacer(minLength: 0)
                    divider
                    Spacer(minLength: 0)

                    footerRow(scale: s)
                        .frame(height: 32 * s)
                }
                .padding(.horizontal, 24 * s)
                .padding(.vertical, 16 * s)
                .frame(width: w, height: h)
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Header

    private func headerRow(scale s: CGFloat) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4 * s) {
                Text(ticket.airline.uppercased())
                    .font(.system(size: 8 * s, weight: .bold))
                    .foregroundStyle(style.textSecondary)

                Text("\(ticket.flightNumber) · Boarding Pass")
                    .font(.system(size: 10 * s, weight: .bold))
                    .tracking(0.44 * s)
                    .foregroundStyle(style.textPrimary)
                    .lineLimit(1)
            }

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
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(style.divider)
            .frame(height: 1)
    }

    // MARK: - Route row

    private func routeRow(scale s: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 0) {
            airportBlock(
                code: ticket.origin,
                name: ticket.originName,
                location: ticket.originLocation,
                alignment: .leading,
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
                alignment: .trailing,
                scale: s
            )
        }
        .padding(.horizontal, 24 * s)
    }

    private func airportBlock(
        code: String,
        name: String,
        location: String,
        alignment: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        let textAlign: TextAlignment = (alignment == .leading) ? .leading : .trailing
        return VStack(alignment: alignment, spacing: 4 * s) {
            Text(code)
                .font(.system(size: 40.79 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(name)
                .font(.system(size: 9.41 * s, weight: .bold))
                .tracking(0.38 * s)
                .foregroundStyle(style.textPrimary)
                .multilineTextAlignment(textAlign)
                .lineLimit(1)

            Text(location.uppercased())
                .font(.system(size: 6.28 * s, weight: .regular))
                .tracking(0.75 * s)
                .foregroundStyle(style.textSecondary)
                .multilineTextAlignment(textAlign)
                .lineLimit(1)
        }
        .frame(width: 100 * s, alignment: (alignment == .leading) ? .leading : .trailing)
    }

    // MARK: - Footer

    private func footerRow(scale s: CGFloat) -> some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 16 * s) {
                detailCell(label: "Date",    value: ticket.date,          scale: s)
                pillDivider(scale: s)
                detailCell(label: "Gate",    value: ticket.gate,          scale: s)
                pillDivider(scale: s)
                detailCell(label: "Seat",    value: ticket.seat,          scale: s)
                pillDivider(scale: s)
                detailCell(label: "Departs", value: ticket.departureTime, scale: s)
            }

            Spacer()

            madeWithBadge(scale: s)
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
        }
    }

    private func pillDivider(scale s: CGFloat) -> some View {
        Capsule()
            .fill(style.textPrimary.opacity(0.1))
            .frame(width: 0.78 * s, height: 21.18 * s)
    }

    private func madeWithBadge(scale s: CGFloat) -> some View {
        HStack(spacing: 3.5 * s) {
            Text("Made with")
                .font(.system(size: 7.48 * s, weight: .semibold))
                .tracking(-0.43 * s)
                .foregroundStyle(style.footerText)

            HStack(spacing: 2.5 * s) {
                Image("brand/\(brandSlug)/logomark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 7 * s, height: 7 * s)
                    .background(
                        RoundedRectangle(cornerRadius: 1.236 * s, style: .continuous)
                            .fill(Color(hex: "FFFCF0"))
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 1.236 * s, style: .continuous)
                    )

                Image("brand/\(brandSlug)/full")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 3 * s)
                    .environment(\.colorScheme, style.footerScheme)
            }
        }
        .padding(5.28 * s)
        .background(
            RoundedRectangle(cornerRadius: 5.28 * s, style: .continuous)
                .fill(style.footerFill)
        )
    }
}

// MARK: - Preview

private let studioPreviewTicket = StudioTicket(
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
)

#Preview("Default") {
    StudioTicketView(ticket: studioPreviewTicket)
        .padding(24)
        .background(Color.Background.default)
}

#Preview("All styles") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(TicketTemplateKind.studio.styles) { style in
                VStack(alignment: .leading, spacing: 8) {
                    Text(style.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.Text.secondary)

                    StudioTicketView(ticket: studioPreviewTicket, style: style)
                }
            }
        }
        .padding(24)
    }
    .background(Color.Background.default)
}
