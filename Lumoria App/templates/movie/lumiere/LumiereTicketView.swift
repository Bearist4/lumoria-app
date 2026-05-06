//
//  LumiereTicketView.swift
//  Lumoria App
//
//  Horizontal "Lumiere" movie-category ticket — black stub with the
//  film's poster filling the right 188pt column under a top-to-bottom
//  black gradient. Movie title sits on the left in oversized condensed
//  caps; a 3×3 details grid lays out date / screening / room / row /
//  seat / cinema location below.
//
//  Design: figma.com/design/1vAhPHcA6A3SRsQJkkylIU/Tickets?node-id=374-397
//

import SwiftUI

struct LumiereTicketView: View {
    let ticket: LumiereTicket
    var style: TicketStyleVariant = TicketTemplateKind.lumiere.defaultStyle

    @Environment(\.showsLumoriaWatermark) private var showsLumoriaWatermark

    private let aspectRatio: CGFloat = 455 / 260

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / aspectRatio
            let s = w / 455

            ZStack(alignment: .topLeading) {
                (style.backgroundColor ?? Color.black)
                    .frame(width: w, height: h)

                LumierePoster(urlString: ticket.posterUrl, title: ticket.movieTitle)
                    .frame(width: 188 * s, height: h)
                    .overlay(
                        // Fades the poster into whatever background
                        // the active variant uses — black on Default
                        // / Velvet / Noir, cream on Reel / Matinee —
                        // so the seam is invisible at every theme.
                        LinearGradient(
                            colors: [
                                (style.backgroundColor ?? .black).opacity(0),
                                style.backgroundColor ?? .black,
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: w, height: h, alignment: .trailing)
                    .clipped()

                // Title block — 24pt from top + left, 231pt wide so the
                // right edge sits 12pt off the poster column.
                titleBlock(scale: s)
                    .padding(.leading, 24 * s)
                    .padding(.top, 24 * s)
                    .frame(width: w, height: h, alignment: .topLeading)

                // Details grid — pinned 24pt from the bottom + left so
                // the cinema row hugs the bottom edge regardless of how
                // tall the title block ends up rendering.
                detailsGrid(scale: s)
                    .frame(width: 231 * s, alignment: .leading)
                    .padding(.leading, 24 * s)
                    .padding(.bottom, 24 * s)
                    .frame(width: w, height: h, alignment: .bottomLeading)

                if showsLumoriaWatermark {
                    MadeWithLumoria(style: .white, version: .small, scale: s)
                        .padding(.top, 12 * s)
                        .padding(.trailing, 12 * s)
                        .frame(width: w, height: h, alignment: .topTrailing)
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 24 * s, style: .continuous))
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }

    // MARK: - Title block

    private func titleBlock(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4 * s) {
            Text("NOW SHOWING")
                .font(LumiereFont.barlow(size: 7.5 * s, weight: .regular))
                .tracking(1.4 * s)
                .foregroundStyle(style.accent)

            Text(ticket.movieTitle.uppercased())
                .font(LumiereFont.barlow(size: 29 * s, weight: .black))
                .tracking(-1.24 * s)
                .foregroundStyle(style.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            if !ticket.director.isEmpty {
                Text(ticket.director)
                    .font(LumiereFont.barlow(size: 10.5 * s, weight: .light))
                    .tracking(0.42 * s)
                    .foregroundStyle(style.textPrimary.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .frame(width: 231 * s, alignment: .leading)
    }

    // MARK: - Details grid

    private func detailsGrid(scale s: CGFloat) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 4 * s, verticalSpacing: 8 * s) {
            GridRow {
                detailCell(label: "Date",      value: ticket.date, scale: s)
                detailCell(label: "Screening", value: ticket.time, scale: s)
                // Empty 3rd column — `gridCellUnsizedAxes` keeps it
                // from expanding vertically, which is what was
                // stretching this row before.
                Color.clear
                    .gridCellUnsizedAxes([.horizontal, .vertical])
            }
            GridRow {
                detailCell(label: "Room", value: ticket.roomNumber, scale: s)
                detailCell(label: "Row",  value: ticket.row,        scale: s)
                detailCell(label: "Seat", value: ticket.seat,       scale: s)
            }
            GridRow {
                detailCell(label: "Cinema", value: ticket.cinemaLocation, scale: s)
                    .gridCellColumns(3)
            }
        }
    }

    private func detailCell(
        label: String,
        value: String,
        scale s: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).textCase(.uppercase)
                .font(LumiereFont.barlow(size: 7 * s, weight: .regular))
                .tracking(1.05 * s)
                .foregroundStyle(style.accent)
            Text(value)
                .font(LumiereFont.barlow(size: 12 * s, weight: .bold))
                .foregroundStyle(style.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Poster

/// Renders the OMDb poster from `MoviePosterImageCache`. The cache is
/// read synchronously so `ImageRenderer` snapshots (export pipeline)
/// and fast-scrolling lists pick up the artwork without waiting on
/// `AsyncImage` — which doesn't fire inside a snapshot at all and is
/// unreliable in scrolling cell reuse. On miss, the view kicks off a
/// load in `.task` and stores the resulting image in `@State`.
struct LumierePoster: View {
    let urlString: String
    let title: String

    @State private var loadedImage: UIImage?

    private var url: URL? {
        guard !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        // GeometryReader gives concrete dimensions so the .top
        // alignment in `.frame(width:height:alignment:)` is honoured —
        // `maxWidth: .infinity` lets the view grow to the image's
        // natural size and short-circuits the clip / alignment.
        GeometryReader { geo in
            Group {
                if let resolved = currentImage {
                    Image(uiImage: resolved)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: geo.size.width,
                            height: geo.size.height,
                            alignment: .top
                        )
                        .clipped()
                } else {
                    placeholder
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .task(id: urlString) {
            // urlString is the dependency: clearing the title must drop
            // the previously-loaded poster, otherwise the stale image
            // keeps painting after the user wipes the field.
            guard let url else {
                loadedImage = nil
                return
            }
            loadedImage = await MoviePosterImageCache.shared.load(from: url)
        }
    }

    /// Prefer the just-loaded `@State` image, then the synchronous
    /// cache hit (covers gallery / export render paths where the cache
    /// was warmed elsewhere). Returns nil → placeholder paints.
    private var currentImage: UIImage? {
        if let loadedImage { return loadedImage }
        if let url { return MoviePosterImageCache.shared.image(for: url) }
        return nil
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.13),
                    Color(red: 0.18, green: 0.13, blue: 0.20),
                    Color(red: 0.28, green: 0.18, blue: 0.24),
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            Image(systemName: "film.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white.opacity(0.18))
                .padding(.horizontal, 36)
                .padding(.vertical, 28)
        }
    }
}

// MARK: - Font

/// Loader for Barlow with a system-italic fallback so the template
/// still renders if the font isn't registered yet. Mirrors the
/// pattern used by ConcertFont.
enum LumiereFont {

    enum Weight {
        case light, regular, bold, black

        var postScript: [String] {
            switch self {
            case .light:   return ["Barlow-Light"]
            case .regular: return ["Barlow-Regular"]
            case .bold:    return ["Barlow-Bold"]
            case .black:   return ["Barlow-Black", "Barlow-ExtraBold"]
            }
        }

        var systemWeight: Font.Weight {
            switch self {
            case .light:   return .light
            case .regular: return .regular
            case .bold:    return .bold
            case .black:   return .black
            }
        }
    }

    static func barlow(size: CGFloat, weight: Weight) -> Font {
        for name in weight.postScript where UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight.systemWeight)
    }
}

// MARK: - Preview

private let lumierePreviewTicket = LumiereTicket(
    movieTitle: "Dune Part Two",
    director: "Denis Villeneuve",
    cinemaLocation: "Pathé Beaugrenelle",
    date: "21 Jun 2026",
    time: "20:30",
    roomNumber: "12",
    row: "K",
    seat: "14",
    posterUrl: ""
)

#Preview("Lumiere — horizontal") {
    LumiereTicketView(ticket: lumierePreviewTicket)
        .padding(24)
        .background(Color.Background.default)
}
