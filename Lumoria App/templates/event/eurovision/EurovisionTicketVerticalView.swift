//
//  EurovisionTicketVerticalView.swift
//  Lumoria App
//
//  Vertical "Eurovision" event-category ticket — Vienna 2026 grand
//  finale stub. Layout follows Figma node 325:1747:
//
//    • full-bleed `eurovision-bg-<cc>` background (per country)
//    • top-center "Grand Finale" pill (linear gradient text)
//    • centered country logo (`eurovision-logo-<cc>`)
//    • "Vienna 2026" title
//    • bottom 2-row details grid (date + venue / row · section · seat)
//    • full-width "Made with Lumoria" footer bar
//

import SwiftUI
import UIKit

struct EurovisionTicketVerticalView: View {
    let ticket: EurovisionTicket
    var style: TicketStyleVariant = TicketTemplateKind.eurovision.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack(alignment: .top) {
                EurovisionBackground(
                    assetName: "eurovision-bg-v",
                    fallback: style.swatch.background
                )
                .frame(width: w, height: h)

                VStack(spacing: 0) {
                    EurovisionGrandFinalePill(scale: s, style: .linear)
                        .padding(.top, 57 * s)

                    centerLogo(scale: s)
                        .padding(.top, 48 * s)
                        // Hug the rendered logo so the gap to "Vienna
                        // 2026" below isn't padded out by reserved
                        // empty space inside the logo's max-frame.
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Vienna 2026")
                        .font(.system(size: 15 * s, weight: .bold, design: .rounded))
                        .foregroundStyle(style.textPrimary)
                        .padding(.top, 16 * s)

                    Spacer(minLength: 0)

                    detailsGrid(scale: s)
                        .padding(.horizontal, 16 * s)
                        .padding(.bottom, 16 * s + 40 * s) // leave room for the strip
                }
                .frame(width: w, height: h)

                // "Made with Lumoria" footer — same pattern as Studio
                // vertical: a ticket-sized container with the strip
                // anchored to the bottom, masked by the bg image so
                // the strip conforms to the ticket silhouette (rounded
                // corners, future notches) instead of being a flat
                // full-width slab.
                if showsLumoriaWatermark {
                    ZStack(alignment: .bottom) {
                        Color.clear
                        footerBar(scale: s)
                            .frame(height: 40 * s)
                    }
                    .frame(width: w, height: h)
                    .mask {
                        if UIImage(named: "eurovision-bg-v") != nil {
                            Image("eurovision-bg-v")
                                .resizable()
                                .scaledToFill()
                                .frame(width: w, height: h)
                        } else {
                            // No bg art yet — fall back to the parent
                            // rounded-rect so the strip's bottom
                            // corners still curve with the ticket.
                            RoundedRectangle(cornerRadius: 32 * s, style: .continuous)
                        }
                    }
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 32 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Center logo

    @ViewBuilder
    private func centerLogo(scale s: CGFloat) -> some View {
        let assetName = ticket.countryCode.isEmpty
            ? nil
            : "eurovision-logo-\(ticket.countryCode)"
        EurovisionLogo(
            assetName: assetName,
            country: EurovisionCountry.fromIsoCode(ticket.countryCode),
            displayName: ticket.countryName,
            maxHeight: 140 * s,
            maxWidth: 220 * s
        )
    }

    // MARK: - Details grid

    /// Vertical layout: row 1 = date + venue side-by-side; row 2 swaps
    /// based on attendance — in-person shows Row/Area/Seat across three
    /// cells, at-home collapses to a single full-width "Watching from"
    /// cell.
    @ViewBuilder
    private func detailsGrid(scale s: CGFloat) -> some View {
        VStack(spacing: 4 * s) {
            HStack(spacing: 4 * s) {
                detailCell(label: "Date",  value: ticket.date,  scale: s)
                detailCell(label: "Venue", value: ticket.venue, scale: s)
            }
            switch ticket.attendanceMode {
            case .inPerson:
                HStack(spacing: 4 * s) {
                    detailCell(label: "Row",  value: ticket.row,     scale: s)
                    detailCell(label: "Area", value: ticket.section, scale: s)
                    detailCell(label: "Seat", value: ticket.seat,    scale: s)
                }
            case .atHome:
                detailCell(
                    label: "Watching from",
                    value: ticket.watchLocation,
                    scale: s
                )
            }
        }
    }

    private func detailCell(
        label: String,
        value: String,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 6 * s) {
            Text(label.uppercased())
                .font(.system(size: 7 * s, weight: .regular))
                .tracking(1.05 * s)
                .foregroundStyle(style.textPrimary.opacity(0.85))
                .lineLimit(1)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 10 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8 * s)
        .background(
            RoundedRectangle(cornerRadius: 8 * s, style: .continuous)
                .fill(Color.black.opacity(0.07))
        )
    }

    // MARK: - Footer bar

    /// Full-width "Made with Lumoria" strip. The bar is the topmost
    /// layer at the bottom of the ticket; the parent ZStack's outer
    /// `.clipShape(RoundedRectangle)` is what crops the bar's bottom
    /// corners to the ticket silhouette, matching the chrome of every
    /// other vertical template.
    private func footerBar(scale s: CGFloat) -> some View {
        MadeWithLumoria(
            style: .black,
            version: .full,
            scale: s,
            fullWidth: true
        )
    }
}

// MARK: - Preview

private let eurovisionPreviewTicket = EurovisionTicket(
    countryCode: EurovisionCountry.france.isoCode,
    countryName: EurovisionCountry.france.displayName,
    date: "16 May. 2026",
    venue: "Stadthalle Halle D",
    attendance: EurovisionAttendance.inPerson.rawValue,
    section: "Floor",
    row: "GA",
    seat: "OPEN",
    watchLocation: "",
    ticketNumber: "ESC-2026-000142"
)

#Preview("Eurovision — vertical") {
    EurovisionTicketVerticalView(ticket: eurovisionPreviewTicket)
        .padding(32)
        .background(Color.Background.default)
}
