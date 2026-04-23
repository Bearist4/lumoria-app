//
//  ConcertTicketView.swift
//  Lumoria App
//
//  Horizontal "Concert" event-category ticket — dreamy pop-concert
//  stub with a curved artist name arcing across the top, a heart
//  cutout as focal motif, and a Date / Doors / Show / Venue grid at
//  the bottom.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=195-948
//
//  The curved artist arc follows the approach from
//  stackoverflow.com/a/77280669 — each character's angle along the arc
//  is computed from the running arc-length (`width / radius`), so
//  spacing stays visually even regardless of character metrics.
//

import SwiftUI
import UIKit

struct ConcertTicketView: View {
    let ticket: ConcertTicket
    var style: TicketStyleVariant = TicketTemplateKind.concert.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .topLeading) {
                background(width: w, height: h)

                VStack(spacing: 0) {
                    headerBadge(scale: s)
                        .padding(.top, 10 * s)

                    titleArc(scale: s)
                        .padding(.top, 2 * s)

                    subtitle(scale: s)
                        .padding(.top, -6 * s)

                    Spacer(minLength: 0)

                    detailsRow(scale: s)
                        .padding(.horizontal, 26 * s)
                        .padding(.bottom, 40 * s)
                }
                .frame(width: w, height: h)

                footerStrip(scale: s)
                    .frame(width: w, height: h, alignment: .bottom)
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 24 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Background

    /// Artwork lives in the `concert-bg` asset slot (the designer-
    /// supplied gradient + heart composition). When the asset is
    /// missing we draw the swatch fill so the template still renders —
    /// useful for preview-on-device before the artwork lands.
    @ViewBuilder
    private func background(width w: CGFloat, height h: CGFloat) -> some View {
        if let asset = style.backgroundAsset, UIImage(named: asset) != nil {
            Image(asset)
                .resizable()
                .frame(width: w, height: h)
        } else {
            style.swatch.background
                .frame(width: w, height: h)
        }
    }

    // MARK: - Header badge ("Made with Lumoria")

    @ViewBuilder
    private func headerBadge(scale s: CGFloat) -> some View {
        if showsLumoriaWatermark {
            MadeWithLumoria(style: .black, version: .small, scale: s)
        } else {
            // Reserve the same vertical space so the arc sits where
            // the Figma places it whether or not the watermark shows.
            Color.clear.frame(height: 24 * s)
        }
    }

    // MARK: - Curved artist name

    /// Radius shared by the artist arc and the tour-subtitle arc, so
    /// both lines sit on the same concentric curve.
    private func titleRadius(scale s: CGFloat) -> CGFloat { 820 * s }

    /// Radius tuned to match the Figma arc rise. Chord width ≈ 380pt,
    /// rise ≈ 22pt at 1× scale → r ≈ 380² / (8 · 22) ≈ 820. Long artist
    /// names (e.g. "Sabrina Carpenter") that would overshoot the chord
    /// are split at the most balanced word boundary and rendered as two
    /// stacked arcs — the tour subtitle sits below the VStack so it
    /// automatically follows the artist line count.
    private func titleArc(scale s: CGFloat) -> some View {
        let fontSize = 44 * s
        let font = ConcertFont.momoTrustDisplay(size: fontSize)
        let kerning: CGFloat = -0.5 * s
        let maxChord = 455 * s - 60 * s
        let lines = Self.splitArtistForArc(
            ticket.artist,
            font: font,
            kerning: kerning,
            radius: titleRadius(scale: s),
            maxChord: maxChord
        )
        return VStack(spacing: -10 * s) {
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

    // MARK: - Tour subtitle

    /// Curved to match the artist arc on the same radius, so the two
    /// lines read as concentric rings of the Figma composition.
    private func subtitle(scale s: CGFloat) -> some View {
        let fontSize = 10 * s
        return ConcertCurvedText(
            text: ticket.tourName.uppercased(),
            radius: titleRadius(scale: s),
            uiFont: .systemFont(ofSize: fontSize, weight: .medium),
            color: style.textSecondary,
            kerning: 2.8 * s
        )
        .frame(height: fontSize * 1.1)
    }


    // MARK: - Details (Date · Doors · Show · Venue)

    private func detailsRow(scale s: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            detailCell(label: "Date",  value: ticket.date,      alignment: .leading,  scale: s)
            detailCell(label: "Doors", value: ticket.doorsTime, alignment: .center,   scale: s)
            detailCell(label: "Show",  value: ticket.showTime,  alignment: .center,   scale: s)
            detailCell(label: "Venue", value: ticket.venue,     alignment: .trailing, scale: s)
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
                .font(.system(size: 8 * s, weight: .medium))
                .tracking(2.45 * s)
                .foregroundStyle(style.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 13 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(
            maxWidth: .infinity,
            alignment: alignment == .leading  ? .leading
                     : alignment == .trailing ? .trailing
                     : .center
        )
    }

    // MARK: - Footer strip (Live in concert · Ticket # · Admit badge)

    private func footerStrip(scale s: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text("LIVE IN CONCERT · TOUR 2026")
                .font(.system(size: 11 * s, weight: .medium))
                .tracking(1.6 * s)
                .foregroundStyle(style.textPrimary.opacity(0.85))
                .lineLimit(1)

            Spacer(minLength: 12 * s)

            Text(ticket.ticketNumber)
                .font(.system(size: 11 * s))
                .tracking(2.8 * s)
                .foregroundStyle(style.textPrimary.opacity(0.55))
                .lineLimit(1)

            Spacer(minLength: 12 * s)

            admitBadge(scale: s)
        }
        .padding(.horizontal, 26 * s)
        .padding(.bottom, 12 * s)
    }

    private func admitBadge(scale s: CGFloat) -> some View {
        Text("ADMIT ONE")
            .font(.system(size: 11 * s, weight: .semibold))
            .tracking(2.1 * s)
            .foregroundStyle(style.onAccent)
            .lineLimit(1)
            .padding(.horizontal, 12 * s)
            .padding(.vertical, 4 * s)
            .background(
                Capsule()
                    .fill(style.footerFill.opacity(0.85))
            )
    }
}

// MARK: - Shared fonts

/// Font loader shared by both concert templates. Looks up Momo Trust
/// Display by a handful of likely PostScript names, then falls back to
/// fuzzy-matching any registered family whose name contains "momo" or
/// "trust". If nothing matches, callers get a system italic so the
/// template still renders while the font is being wired up.
enum ConcertFont {

    static func momoTrustDisplay(size: CGFloat) -> UIFont {
        if let resolved = resolvedMomoFontName,
           let font = UIFont(name: resolved, size: size) {
            return font
        }
        return UIFont.italicSystemFont(ofSize: size)
    }

    /// Resolved once per process — the font registry doesn't change at
    /// runtime, so repeated family-name scans are wasted work.
    private static let resolvedMomoFontName: String? = {
        let candidates = [
            "MomoTrustDisplay-Regular",
            "MomoTrustDisplay-Medium",
            "MomoTrustDisplay-Bold",
            "MomoTrustDisplay",
            "Momo Trust Display",
            "Momo_Trust_Display",
        ]
        for name in candidates where UIFont(name: name, size: 12) != nil {
            return name
        }
        for family in UIFont.familyNames
            where family.localizedCaseInsensitiveContains("momo")
               || family.localizedCaseInsensitiveContains("trust")
        {
            let names = UIFont.fontNames(forFamilyName: family)
            #if DEBUG
            print("[Concert] Found candidate font family '\(family)' → \(names)")
            #endif
            if let first = names.first { return first }
        }
        #if DEBUG
        print("[Concert] Momo Trust Display not found. Registered families:")
        for f in UIFont.familyNames.sorted() { print("  • \(f)") }
        #endif
        return nil
    }()
}

// MARK: - Curved text primitive

/// Renders `text` along a circular arc, preserving per-character
/// tangent rotation and even spacing. Arc center sits below the
/// middle of the arc so the middle character is highest.
///
/// Based on stackoverflow.com/a/77280669 — the key trick is that each
/// character's angle is driven by its actual rendered width divided by
/// the arc's radius, not by an equal angular slice. Otherwise wide
/// glyphs (M, W) and narrow ones (i, l) would space unevenly along
/// the arc.
struct ConcertCurvedText: View {
    let text: String
    let radius: CGFloat
    let uiFont: UIFont
    let color: Color
    let kerning: CGFloat

    var body: some View {
        let chars = Array(text)
        // Per-char glyph widths using the exact same UIFont — this is
        // what keeps the spacing visually even.
        let widths: [CGFloat] = chars.map { ch in
            (String(ch) as NSString)
                .size(withAttributes: [.font: uiFont])
                .width
        }
        let gapCount = CGFloat(max(0, chars.count - 1))
        let totalWidth = widths.reduce(0, +) + kerning * gapCount
        let totalAngle = totalWidth / radius

        var cumulative: CGFloat = 0
        let charAngles: [CGFloat] = chars.indices.map { i in
            let mid = cumulative + widths[i] / 2
            cumulative += widths[i] + kerning
            return mid / radius - totalAngle / 2
        }

        return ZStack {
            ForEach(Array(chars.enumerated()), id: \.offset) { i, ch in
                let angle = charAngles[i]
                Text(String(ch))
                    .font(Font(uiFont))
                    .foregroundStyle(color)
                    .rotationEffect(.radians(Double(angle)), anchor: .center)
                    .offset(
                        x: radius * CGFloat(sin(Double(angle))),
                        y: -radius * CGFloat(cos(Double(angle))) + radius
                    )
            }
        }
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

#Preview("Concert — horizontal") {
    ConcertTicketView(ticket: concertPreviewTicket)
        .padding(24)
        .background(Color.Background.default)
}
