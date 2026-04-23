//
//  ConcertTicketVerticalView.swift
//  Lumoria App
//
//  Vertical "Concert" event-category ticket — same language as the
//  horizontal variant, laid out portrait. Layout mirrors Figma
//  node 195:947:
//
//    • curved artist arc at the top
//    • tour subtitle
//    • "Made with Lumoria" pill under the subtitle
//    • 2×2 details grid (Date/Doors, Show/Venue)
//    • centred ADMIT ONE pill
//    • "LIVE IN CONCERT · TOUR 2026" + ticket number
//
//  All decorative artwork (hearts, stars, central heart cutout) lives
//  in the `concert-bg-vertical` asset so every variant can ship its
//  own colourway without touching the view.
//

import SwiftUI
import UIKit

struct ConcertTicketVerticalView: View {
    let ticket: ConcertTicket
    var style: TicketStyleVariant = TicketTemplateKind.concert.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 260 / 455

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 260

            ZStack(alignment: .top) {
                background(width: w, height: h)

                VStack(spacing: 0) {
                    titleArc(scale: s)
                        .padding(.top, 42 * s)

                    subtitle(scale: s)
                        .padding(.top, 2 * s)

                    if showsLumoriaWatermark {
                        MadeWithLumoria(style: .black, version: .small, scale: s)
                            .padding(.top, 14 * s)
                    }

                    Spacer(minLength: 0)

                    detailsGrid(scale: s)
                        .padding(.horizontal, 28 * s)
                        .padding(.bottom, 16 * s)

                    footer(scale: s)
                        .padding(.bottom, 42 * s)
                }
                .frame(width: w, height: h)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 24 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Background

    @ViewBuilder
    private func background(width w: CGFloat, height h: CGFloat) -> some View {
        let verticalAsset = style.backgroundAsset.map { "\($0)-vertical" }
        if let asset = verticalAsset, UIImage(named: asset) != nil {
            Image(asset).resizable().frame(width: w, height: h)
        } else if let asset = style.backgroundAsset, UIImage(named: asset) != nil {
            // Fallback to horizontal artwork when the vertical variant
            // hasn't landed yet.
            Image(asset).resizable().frame(width: w, height: h)
        } else {
            style.swatch.background.frame(width: w, height: h)
        }
    }

    // MARK: - Curved title

    /// Shared radius for the artist arc and the tour-subtitle arc —
    /// both lines sit on the same concentric curve, tighter than the
    /// horizontal variant to match the narrower frame.
    private func titleRadius(scale s: CGFloat) -> CGFloat { 420 * s }

    /// Vertical variant uses a tighter radius so the same "Madison
    /// Beer" string curves more inside the narrower frame. Long
    /// artist names (e.g. "Sabrina Carpenter") that would overshoot
    /// the ticket chord are split at the most balanced word boundary
    /// and rendered as two stacked arcs — this pushes the tour
    /// subtitle below the second line naturally.
    private func titleArc(scale s: CGFloat) -> some View {
        let fontSize = 34 * s
        let font = ConcertFont.momoTrustDisplay(size: fontSize)
        let kerning: CGFloat = -0.4 * s
        let maxChord = 260 * s - 48 * s
        let lines = Self.splitArtistForArc(
            ticket.artist,
            font: font,
            kerning: kerning,
            radius: titleRadius(scale: s),
            maxChord: maxChord
        )
        return VStack(spacing: -8 * s) {
            ForEach(lines.indices, id: \.self) { i in
                ConcertCurvedText(
                    text: lines[i],
                    radius: titleRadius(scale: s),
                    uiFont: font,
                    color: style.textPrimary,
                    kerning: kerning
                )
                .frame(height: fontSize * 1.2)
            }
        }
    }

    /// Measures the arc chord the name would subtend and, if it
    /// overshoots `maxChord`, splits at the space that balances the
    /// two halves' rendered width most evenly. Single-word names
    /// render on one line regardless.
    private static func splitArtistForArc(
        _ text: String,
        font: UIFont,
        kerning: CGFloat,
        radius: CGFloat,
        maxChord: CGFloat
    ) -> [String] {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let gapCount = CGFloat(max(0, text.count - 1))
        let arcLen = (text as NSString).size(withAttributes: attrs).width
                   + kerning * gapCount
        let angle = arcLen / radius
        let chord = 2 * radius * CGFloat(sin(Double(angle) / 2))
        if chord <= maxChord { return [text] }

        let words = text.split(separator: " ").map(String.init)
        guard words.count >= 2 else { return [text] }

        var bestSplit = 1
        var bestDiff: CGFloat = .infinity
        for i in 1..<words.count {
            let a = words[0..<i].joined(separator: " ")
            let b = words[i..<words.count].joined(separator: " ")
            let wa = (a as NSString).size(withAttributes: attrs).width
            let wb = (b as NSString).size(withAttributes: attrs).width
            let diff = abs(wa - wb)
            if diff < bestDiff { bestDiff = diff; bestSplit = i }
        }
        let line1 = words[0..<bestSplit].joined(separator: " ")
        let line2 = words[bestSplit..<words.count].joined(separator: " ")
        return [line1, line2]
    }

    /// Curved to match the artist arc on the same radius so the two
    /// lines read as concentric rings.
    private func subtitle(scale s: CGFloat) -> some View {
        let fontSize = 9 * s
        return ConcertCurvedText(
            text: ticket.tourName.uppercased(),
            radius: titleRadius(scale: s),
            uiFont: .systemFont(ofSize: fontSize, weight: .medium),
            color: style.textSecondary,
            kerning: 2.4 * s
        )
        .frame(height: fontSize * 1.1)
    }

    // MARK: - Details (2×2 grid)

    private func detailsGrid(scale s: CGFloat) -> some View {
        VStack(spacing: 8 * s) {
            HStack(spacing: 0) {
                detailCell(label: "Date",  value: ticket.date,      alignment: .leading,  scale: s)
                detailCell(label: "Doors", value: ticket.doorsTime, alignment: .trailing, scale: s)
            }
            HStack(spacing: 0) {
                detailCell(label: "Show",  value: ticket.showTime,  alignment: .leading,  scale: s)
                detailCell(label: "Venue", value: ticket.venue,     alignment: .trailing, scale: s)
            }
        }
    }

    private func detailCell(
        label: String,
        value: String,
        alignment: HorizontalAlignment,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: alignment, spacing: 6 * s) {
            Text(label.uppercased())
                .font(.custom("Barlow-Medium", size: 8 * s))
                .tracking(2.45 * s)
                .foregroundStyle(style.textSecondary)
            Text(value)
                .font(.system(size: 17 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(
            maxWidth: .infinity,
            alignment: alignment == .leading ? .leading : .trailing
        )
    }

    // MARK: - Footer (ADMIT ONE + live strip + ticket number)

    private func footer(scale s: CGFloat) -> some View {
        VStack(spacing: 4 * s) {
            admitBadge(scale: s)

            Text("LIVE IN CONCERT · TOUR 2026")
                .font(.system(size: 11 * s, weight: .medium))
                .tracking(1.6 * s)
                .foregroundStyle(style.textPrimary.opacity(0.85))

            Text(ticket.ticketNumber)
                .font(.system(size: 11 * s))
                .tracking(2.8 * s)
                .foregroundStyle(style.textPrimary.opacity(0.55))
        }
    }

    private func admitBadge(scale s: CGFloat) -> some View {
        Text("ADMIT ONE")
            .font(.system(size: 11 * s, weight: .semibold))
            .foregroundStyle(style.onAccent)
            .lineLimit(1)
            .padding(.horizontal, 12 * s)
            .padding(.vertical, 4 * s)
            .background(
                Capsule().fill(style.footerFill.opacity(0.85))
            )
    }
}

// MARK: - Preview

private let concertPreviewTicket = ConcertTicket(
    artist: "Madison Beer",
    tourName: "The Locket Tour",
    venue: "O2 Arena",
    date: "21 Jun 2026",
    doorsTime: "19:00",
    showTime: "20:30",
    ticketNumber: "CON-2026-000142"
)

#Preview("Concert — vertical") {
    ConcertTicketVerticalView(ticket: concertPreviewTicket)
        .padding(32)
        .background(Color.Background.default)
}
