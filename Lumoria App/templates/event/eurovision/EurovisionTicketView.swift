//
//  EurovisionTicketView.swift
//  Lumoria App
//
//  Horizontal "Eurovision" event-category ticket — Vienna 2026 grand
//  finale stub. Layout follows Figma node 324:1464:
//
//    • full-bleed `eurovision-bg-<cc>` background (per country)
//    • top-left "Made with Lumoria" pill
//    • top-right "Grand Finale" gradient pill
//    • centered country logo (`eurovision-logo-<cc>`)
//    • "Vienna 2026" title
//    • bottom 5-cell details strip — Date · Section · Seat · Row · Venue
//
//  Per-country artwork lives in `Assets.xcassets/tickets/eurovision/`
//  as 70 empty image-set slots (35 backgrounds + 35 logos). Drop a PNG
//  into a slot to ship a variant; the renderer falls back to a swatch
//  + flag emoji when an asset is missing so unfilled slots still show
//  a usable ticket.
//

import SwiftUI
import UIKit

struct EurovisionTicketView: View {
    let ticket: EurovisionTicket
    var style: TicketStyleVariant = TicketTemplateKind.eurovision.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .topLeading) {
                EurovisionBackground(
                    assetName: "eurovision-bg-h",
                    fallback: style.swatch.background
                )
                .frame(width: w, height: h)

                centerLogo(scale: s)
                    .frame(width: w, height: h, alignment: .center)

                titleLabel(scale: s)
                    .frame(width: w, height: h, alignment: .center)
                    .offset(y: 8 * s)

                topBar(scale: s)
                    .padding(.horizontal, 16 * s)
                    .padding(.top, 16 * s)

                detailsStrip(scale: s)
                    .frame(width: w, height: h, alignment: .bottom)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 32 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Top bar

    @ViewBuilder
    private func topBar(scale s: CGFloat) -> some View {
        HStack(alignment: .top) {
            if showsLumoriaWatermark {
                MadeWithLumoria(style: .white, version: .small, scale: s)
            } else {
                Color.clear.frame(height: 24 * s)
            }
            Spacer(minLength: 0)
            EurovisionGrandFinalePill(scale: s, style: .radial)
        }
    }

    // MARK: - Center logo

    /// `eurovision-logo-<cc>` is the per-country composite (heart +
    /// "EUROVISION" wordmark + country tag). When the asset is missing
    /// we paint a translucent flag-emoji placeholder so the ticket still
    /// reads as belonging to the picked country.
    @ViewBuilder
    private func centerLogo(scale s: CGFloat) -> some View {
        let assetName = ticket.countryCode.isEmpty
            ? nil
            : "eurovision-logo-\(ticket.countryCode)"
        EurovisionLogo(
            assetName: assetName,
            country: EurovisionCountry.fromIsoCode(ticket.countryCode),
            displayName: ticket.countryName,
            maxHeight: 110 * s,
            maxWidth: 240 * s
        )
        .offset(y: -18 * s)
    }

    // MARK: - "Vienna 2026" title

    private func titleLabel(scale s: CGFloat) -> some View {
        Text("Vienna 2026")
            .font(.system(size: 15 * s, weight: .bold, design: .rounded))
            .foregroundStyle(style.textPrimary)
            .offset(y: 30 * s)
    }

    // MARK: - Details strip (bottom)

    /// Horizontal layout: cells depend on attendance mode.
    /// In-person → Date · Area · Seat · Row · Venue (Date/Venue fill,
    /// the three numeric cells hug their ≤3-char values).
    /// At-home → Date · Watching from · Venue (all three fill).
    @ViewBuilder
    private func detailsStrip(scale s: CGFloat) -> some View {
        HStack(spacing: 4 * s) {
            switch ticket.attendanceMode {
            case .inPerson:
                detailCell(label: "Date",  value: ticket.date,    fills: true,  scale: s)
                detailCell(label: "Area",  value: ticket.section, fills: false, scale: s)
                detailCell(label: "Seat",  value: ticket.seat,    fills: false, scale: s)
                detailCell(label: "Row",   value: ticket.row,     fills: false, scale: s)
                detailCell(label: "Venue", value: ticket.venue,   fills: true,  scale: s)
            case .atHome:
                detailCell(label: "Date",          value: ticket.date,          fills: true, scale: s)
                detailCell(label: "Watching from", value: ticket.watchLocation, fills: true, scale: s)
                detailCell(label: "Venue",         value: ticket.venue,         fills: true, scale: s)
            }
        }
        .padding(.horizontal, 24 * s)
        .padding(.top, 16 * s)
        .padding(.bottom, 24 * s)
    }

    /// `fills == true` → cell stretches via `maxWidth: .infinity` (date,
    /// venue). `fills == false` → cell hugs its value (section, seat,
    /// row — never more than ~3 chars).
    private func detailCell(
        label: String,
        value: String,
        fills: Bool,
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
        .frame(maxWidth: fills ? .infinity : nil, alignment: .leading)
        .fixedSize(horizontal: !fills, vertical: false)
        .padding(8 * s)
        .background(
            RoundedRectangle(cornerRadius: 8 * s, style: .continuous)
                .fill(Color.black.opacity(0.07))
        )
    }
}

// MARK: - Preview

private let eurovisionPreviewTicket = EurovisionTicket(
    countryCode: EurovisionCountry.austria.isoCode,
    countryName: EurovisionCountry.austria.displayName,
    date: "16 May. 2026",
    venue: "Stadthalle Halle D",
    attendance: EurovisionAttendance.inPerson.rawValue,
    section: "Floor",
    row: "GA",
    seat: "OPEN",
    watchLocation: "",
    ticketNumber: "ESC-2026-000142"
)

#Preview("Eurovision — horizontal") {
    EurovisionTicketView(ticket: eurovisionPreviewTicket)
        .padding(24)
        .background(Color.Background.default)
}
