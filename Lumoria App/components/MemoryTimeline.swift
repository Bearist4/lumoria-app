//
//  MemoryTimeline.swift
//  Lumoria App
//
//  Horizontal film strip that sits at the bottom of `MemoryTimelineView`.
//  A continuous chronological axis: each calendar day gets a fixed width
//  slot, tiles sit on the axis at their actual date, and date labels
//  scroll with the tiles as a single shared surface. A fixed red
//  playhead pinned to the card's center line tracks whichever tile
//  happens to be under it — the parent view uses that binding to grow
//  the matching pin on the map and recenter the camera.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1841-39814
//

import SwiftUI

// MARK: - Stop model

/// Role a ticket location plays on a timeline leg.
enum TimelineTicketRole: Hashable {
    case origin
    case destination
}

/// One entry on the timeline. `.ticket` stops carry the originating
/// ticket + which of its locations this represents so tapping can route
/// into its detail; `.anchor` stops carry the user-defined journey
/// anchor directly.
enum TimelineStop: Identifiable, Hashable {
    case ticket(id: UUID, ticket: Ticket, role: TimelineTicketRole, date: Date)
    case anchor(JourneyAnchor)

    var id: UUID {
        switch self {
        case .ticket(let id, _, _, _): return id
        case .anchor(let a):           return a.id
        }
    }

    var date: Date {
        switch self {
        case .ticket(_, _, _, let d): return d
        case .anchor(let a):          return a.date
        }
    }
}

// MARK: - Timeline

struct MemoryTimeline: View {

    /// Sentinel ID for the left-most "start" anchor. When this is the
    /// selected stop, the parent view knows to show a fit-all overview.
    static let startAnchorId = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    /// Sentinel ID for the right-most "end" anchor.
    static let endAnchorId   = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!

    let stops: [TimelineStop]
    let startDate: Date?
    let endDate: Date?

    @Binding var selectedStopId: UUID?

    /// Most recent scroll direction. Drives the direction of the sticky
    /// date label's slide transition: scrolling forward (→) makes the
    /// new date arrive from the LEFT; scrolling backward (←) makes it
    /// arrive from the RIGHT.
    @State private var scrollDirection: ScrollDirection = .forward

    private enum ScrollDirection { case forward, backward }

    // Layout constants
    /// 24pt interior padding on all sides of the card's content.
    private let cardPadding: CGFloat = 24
    private let tileSize: CGFloat = 56
    /// Edge-to-edge gap between two tiles on the SAME calendar day.
    private let tileSpacing: CGFloat = 16
    /// Distance from the edge of a tile to the center of the moon
    /// separator placed between that tile and the next day's first tile.
    private let moonMargin: CGFloat = 28
    /// Vertical offset of the date-label rail center from the top of
    /// the card (cardPadding + half the label height).
    private let dateRailTop: CGFloat = 34
    /// Vertical offset of the tile row center from the top of the card.
    /// Leaves a 32pt visual gap between the bottom of the date rail and
    /// the top of a tile — dateRailTop (34) + half the label height
    /// (10) + 32pt gap + half the tile height (28) = 104.
    private let tileRowTop: CGFloat = 104
    /// Total card height — top padding (24) + label (20) + gap (32) +
    /// tile (56) + bottom padding (24) = 156.
    private let cardHeight: CGFloat = 156
    /// Horizontal padding at each end of the axis content reserved for
    /// the start and end SF Symbol glyphs so they sit inside the
    /// scrollable content without overflowing the card.
    private let axisEndPadding: CGFloat = 72
    /// Visual gap between the first/last tile edge and the
    /// start/end icon.
    private let endIconGap: CGFloat = 48

    var body: some View {
        ZStack(alignment: .topLeading) {
            card
            cardTickRail
            GeometryReader { proxy in
                axis(viewportWidth: proxy.size.width)
            }
            playhead
            edgeFades
            activeDayLabel
        }
        .frame(height: cardHeight)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                bottomLeadingRadius: 44,
                bottomTrailingRadius: 44,
                topTrailingRadius: 32,
                style: .continuous
            )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Sticky active-day label

    /// Day whose tile is currently under the playhead. Drives the
    /// sticky top-left date label. Maps the start/end anchors to the
    /// first/last stop's day so the label stays meaningful in the
    /// fit-all overview states.
    private var activeDay: Date {
        let cal = Calendar.current
        if selectedStopId == Self.startAnchorId, let first = stops.first {
            return cal.startOfDay(for: first.date)
        }
        if selectedStopId == Self.endAnchorId, let last = stops.last {
            return cal.startOfDay(for: last.date)
        }
        if let id = selectedStopId,
           let stop = stops.first(where: { $0.id == id }) {
            return cal.startOfDay(for: stop.date)
        }
        return cal.startOfDay(for: stops.first?.date ?? Date())
    }

    /// Date label pinned to the top-left corner. Swaps via a slide
    /// transition whenever `activeDay` changes. Direction follows
    /// `scrollDirection`: forward scrolling pulls the new day in from
    /// the left; backward scrolling pulls it in from the right.
    private var activeDayLabel: some View {
        ZStack(alignment: .topLeading) {
            Text(formatted(activeDay))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize()
                .padding(.horizontal, 6)
                .background(Color.black.opacity(0.95))
                .id(activeDay)
                .transition(labelTransition)
        }
        .animation(.easeInOut(duration: 0.25), value: activeDay)
        .padding(.top, cardPadding)
        .padding(.leading, cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    /// Direction-aware slide transition for the sticky date label.
    /// Scrolling forward through the timeline pulls the new date in
    /// from the RIGHT; scrolling backward pulls it in from the LEFT.
    private var labelTransition: AnyTransition {
        switch scrollDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal:   .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    // MARK: - Card background

    private var card: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 32,
            bottomLeadingRadius: 44,
            bottomTrailingRadius: 44,
            topTrailingRadius: 32,
            style: .continuous
        )
        .fill(Color.black.opacity(0.95))
    }

    // MARK: - Axis (scrollable content)

    /// Combined scrollable surface: date labels, moon separators between
    /// days, and tiles all live in one ZStack so they scroll as a unit.
    /// Leading and trailing padding both equal the half viewport width
    /// so the first tile is centered on the playhead at scroll offset 0
    /// and the user can scroll the last tile all the way back to center.
    private func axis(viewportWidth: CGFloat) -> some View {
        let halfWidth = viewportWidth / 2
        // Start anchor sits at content_x=0 and end anchor at content_x=
        // layout.width. Padding on both sides equals halfWidth so:
        //   • offset 0 centers the start anchor on the playhead
        //   • offset == layout.width centers the end anchor
        //   • any tile between can be reached by scrolling to its x.
        let axisLeadingInset = halfWidth
        let trailingPad = halfWidth
        let totalWidth = axisLeadingInset + contentWidth + trailingPad

        let lay = layout

        return ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                // Same-day connector lines — a soft white rail between
                // consecutive tiles that share a calendar day, fading
                // out at both ends so it reads as a link, not a bar.
                ForEach(Array(lay.connectors.enumerated()), id: \.offset) { _, c in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.45),
                            Color.white.opacity(0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: c.endX - c.startX, height: 1)
                    .position(
                        x: axisLeadingInset + (c.startX + c.endX) / 2,
                        y: tileRowTop
                    )
                }

                ForEach(Array(lay.moons.enumerated()), id: \.offset) { _, x in
                    Image(systemName: "moon.zzz.fill")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.35))
                        .position(x: axisLeadingInset + x, y: tileRowTop)
                }

                // Journey-start anchor icon at content_x = 0.
                Image(systemName: "arrow.right.to.line")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(
                        selectedStopId == Self.startAnchorId ? 1 : 0.45
                    ))
                    .position(
                        x: axisLeadingInset + lay.startAnchorX,
                        y: tileRowTop
                    )

                // Journey-end anchor icon at content_x = lay.endAnchorX.
                Image(systemName: "flag.pattern.checkered")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(
                        selectedStopId == Self.endAnchorId ? 1 : 0.45
                    ))
                    .position(
                        x: axisLeadingInset + lay.endAnchorX,
                        y: tileRowTop
                    )

                ForEach(stops, id: \.id) { stop in
                    if let x = lay.tileX[stop.id] {
                        tile(for: stop)
                            .position(x: axisLeadingInset + x, y: tileRowTop)
                            .id(stop.id)
                    }
                }
            }
            .frame(width: totalWidth, height: cardHeight, alignment: .topLeading)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.x
        } action: { oldOffset, newOffset in
            if newOffset > oldOffset {
                scrollDirection = .forward
            } else if newOffset < oldOffset {
                scrollDirection = .backward
            }
            // With leading pad == halfWidth, the start anchor (at
            // content_x = 0) sits at screen center when offset = 0.
            // Scrolling forward by `offset` shifts whichever content_x
            // value equals `offset` under the playhead.
            updateSelection(centerX: newOffset)
        }
    }

    /// Evenly spaced short vertical tick marks drawn behind the date
    /// labels — a ruler rail that sells the "continuous time axis"
    /// feeling even for spans with few stops. Date labels overlay their
    /// local ticks via a matching-color background pill.
    /// Static tick rail that spans the entire card width. Sits behind
    /// the scroll content so tiles and moons glide over a continuous
    /// ruler; the sticky date label's background pill masks ticks
    /// directly behind it. Extends all the way to both card edges so
    /// the rail never visually ends short of the rounded corners.
    private var cardTickRail: some View {
        Canvas { ctx, size in
            let interval: CGFloat = 4
            let tickHeight: CGFloat = 5
            let color = Color.white.opacity(0.35)
            var x: CGFloat = 0
            while x <= size.width {
                let rect = CGRect(x: x, y: dateRailTop - tickHeight / 2,
                                  width: 1, height: tickHeight)
                ctx.fill(Path(rect), with: .color(color))
                x += interval
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    /// Finds the anchor or tile closest to the playhead and updates
    /// the selection binding. Runs on every scroll frame so the map
    /// pin can grow continuously as a tile passes under the playhead,
    /// and so the map snaps back to fit-all when the user scrolls
    /// past the first or last tile and the start/end anchor icon
    /// reaches the center.
    private func updateSelection(centerX: CGFloat) {
        let lay = layout
        var candidates: [(UUID, CGFloat)] = [
            (Self.startAnchorId, lay.startAnchorX),
            (Self.endAnchorId,   lay.endAnchorX),
        ]
        for stop in stops {
            if let x = lay.tileX[stop.id] {
                candidates.append((stop.id, x))
            }
        }
        guard !candidates.isEmpty else { return }
        let nearest = candidates.min { abs($0.1 - centerX) < abs($1.1 - centerX) }
        if let nearest, nearest.0 != selectedStopId {
            selectedStopId = nearest.0
        }
    }

    // MARK: - Layout (content-driven)

    /// One row of positioned layout data computed in a single pass over
    /// `stops`. Tiles sit at fixed 16pt edge-to-edge spacing within a
    /// calendar day; between days a moon separator is injected and the
    /// spacing widens by `2 * moonMargin`. Date labels and same-day
    /// connector segments are derived from the same pass.
    private struct AxisLayout {
        struct Connector { let startX: CGFloat; let endX: CGFloat }
        var tileX: [UUID: CGFloat] = [:]
        var moons: [CGFloat] = []
        var connectors: [Connector] = []
        /// Content x of the start-anchor icon (left edge of the axis).
        var startAnchorX: CGFloat = 0
        /// Content x of the end-anchor icon (right edge of the axis).
        var endAnchorX: CGFloat = 0
        /// Content x of the first tile — used to bring the first tile
        /// to the playhead on appear.
        var firstTileX: CGFloat = 0
        /// Total content width = endAnchorX.
        var width: CGFloat = 0
    }

    /// Distance from an end-anchor icon's center to the neighboring
    /// tile's center. Includes half the icon (~12pt) + the requested
    /// 48pt gap + half the tile.
    private var gutter: CGFloat { 12 + endIconGap + tileSize / 2 }

    private var layout: AxisLayout {
        guard !stops.isEmpty else { return AxisLayout() }

        let cal = Calendar.current
        var out = AxisLayout()
        out.startAnchorX = 0
        out.firstTileX = gutter

        var cursor: CGFloat = gutter
        var prev: TimelineStop? = nil

        for stop in stops {
            if let prevStop = prev {
                let prevDay = cal.startOfDay(for: prevStop.date)
                let day     = cal.startOfDay(for: stop.date)
                if prevDay == day {
                    let prevX = out.tileX[prevStop.id] ?? cursor
                    cursor += tileSize + tileSpacing
                    out.connectors.append(.init(
                        startX: prevX + tileSize / 2,
                        endX:   cursor - tileSize / 2
                    ))
                } else {
                    let prevX = out.tileX[prevStop.id] ?? cursor
                    cursor += tileSize + 2 * moonMargin
                    out.moons.append((prevX + cursor) / 2)
                }
            }
            out.tileX[stop.id] = cursor
            prev = stop
        }

        out.endAnchorX = cursor + gutter
        out.width = out.endAnchorX
        return out
    }

    /// Content width of the scrollable axis — used to size the ZStack
    /// that hosts all positioned elements.
    private var contentWidth: CGFloat { layout.width }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM."
        return f.string(from: date)
    }

    // MARK: - Tile

    @ViewBuilder
    private func tile(for stop: TimelineStop) -> some View {
        let isSelected = selectedStopId == stop.id
        Group {
            switch stop {
            case .ticket(_, let t, _, _):
                categoryTile(category: t.kind.categoryStyle)
            case .anchor(let a):
                anchorTile(kind: a.kind)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
        )
        .scaleEffect(isSelected ? 1.05 : 1)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private func categoryTile(category: TicketCategoryStyle) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(category.backgroundColor)
            .frame(width: tileSize, height: tileSize)
            .overlay(
                Image(systemName: category.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(category.onColor)
            )
    }

    private func anchorTile(kind: JourneyAnchorKind) -> some View {
        let symbol: String = {
            switch kind {
            case .start:    return "house.fill"
            case .end:      return "flag.fill"
            case .waypoint: return "mappin"
            }
        }()
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.gray.opacity(0.8))
            .frame(width: tileSize, height: tileSize)
            .overlay(
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            )
    }

    // MARK: - Playhead

    private var playhead: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(Color.Feedback.Danger.icon)
                .frame(width: 12, height: 8)
            Rectangle()
                .fill(Color.Feedback.Danger.icon)
                .frame(width: 1.5)
        }
        // ZStack alignment is .topLeading for the positioned-axis
        // content, so pin the playhead explicitly to horizontal center.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 42)
        .allowsHitTesting(false)
    }

    // MARK: - Edge fades

    private var edgeFades: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.03)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 80)
            Spacer(minLength: 0)
            LinearGradient(
                colors: [Color.black.opacity(0.03), Color.black.opacity(0.55)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 80)
        }
        .allowsHitTesting(false)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                bottomLeadingRadius: 44,
                bottomTrailingRadius: 44,
                topTrailingRadius: 32,
                style: .continuous
            )
        )
    }
}

// MARK: - Playhead triangle

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Preview

#Preview("Timeline") {
    @Previewable @State var selected: UUID? = nil

    let t1 = UUID()
    let t2 = UUID()
    let t3 = UUID()
    let t4 = UUID()

    let cal = Calendar.current
    let day1 = cal.date(from: DateComponents(year: 2026, month: 6, day: 23))!
    let day2 = cal.date(from: DateComponents(year: 2026, month: 6, day: 24))!
    let day3 = cal.date(from: DateComponents(year: 2026, month: 6, day: 25))!

    let ticket = TicketsStore.sampleTickets[0]

    return ZStack(alignment: .bottom) {
        Color.gray.ignoresSafeArea()
        MemoryTimeline(
            stops: [
                .ticket(id: t1, ticket: ticket, role: .origin,      date: day1),
                .ticket(id: t2, ticket: ticket, role: .destination, date: day2),
                .ticket(id: t3, ticket: ticket, role: .origin,      date: day2),
                .ticket(id: t4, ticket: ticket, role: .destination, date: day3),
            ],
            startDate: day1,
            endDate: day3,
            selectedStopId: $selected
        )
    }
}
