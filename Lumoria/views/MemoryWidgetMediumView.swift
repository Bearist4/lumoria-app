//
//  MemoryWidgetMediumView.swift
//  Lumoria (widget)
//
//  349 × 164 variant — memory header and 3 tilted ticket minis on the
//  left, stats (categories / km / days) on the right. Background is the
//  user's ticket-shaped art drawn by `MemoryWidgetEntryView`.
//

import SwiftUI
import WidgetKit

struct MemoryWidgetMediumView: View {
    let memory: WidgetMemorySnapshot
    let featuredTicketIds: [UUID]

    /// Common dimension: the width of a vertical ticket equals the height
    /// of a horizontal ticket, so all three minis read at the same visual
    /// weight while keeping their natural aspect ratio.
    private static let commonDim: CGFloat = 79.2
    /// Bottoms of all three minis are aligned, then pushed `bottomShift`
    /// points below the widget's bottom edge so they bleed out the bottom
    /// the way the Figma composition suggests.
    private static let bottomShift: CGFloat = 12

    var body: some View {
        HStack(spacing: 10) {
            leftSection
                .frame(maxWidth: .infinity)

            statsSection
                .frame(width: 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Left section

    private var leftSection: some View {
        ZStack(alignment: .topLeading) {
            ticketStack
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            MemoryWidgetHeader(memory: memory)
                .padding(.top, 16)
                .padding(.leading, 16)
                .padding(.trailing, 12)
        }
    }

    private var ticketStack: some View {
        let refs = featuredRefs
        let slotOffsets: [CGFloat] = [-74, -17, 38]
        let slotAngles: [Double] = [-3, -3, 5]
        let count = min(refs.count, 3)

        return ZStack(alignment: .bottom) {
            if count > 0 {
                let ref = refs[0]
                let size = frameSize(for: ref.orientation)
                MiniTicketView(ref: ref)
                    .frame(width: size.width, height: size.height)
                    .rotationEffect(.degrees(slotAngles[0]))
                    .offset(x: slotOffsets[0], y: Self.bottomShift)
            }
            if count > 1 {
                let ref = refs[1]
                let size = frameSize(for: ref.orientation)
                MiniTicketView(ref: ref)
                    .frame(width: size.width, height: size.height)
                    .rotationEffect(.degrees(slotAngles[1]))
                    .offset(x: slotOffsets[1], y: Self.bottomShift)
            }
            if count > 2 {
                let ref = refs[2]
                let size = frameSize(for: ref.orientation)
                MiniTicketView(ref: ref)
                    .frame(width: size.width, height: size.height)
                    .rotationEffect(.degrees(slotAngles[2]))
                    .offset(x: slotOffsets[2], y: Self.bottomShift)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .bottom)
    }

    /// Per-orientation frame that keeps every ticket mini at the same
    /// visual weight — the width of a vertical card equals the height of
    /// a horizontal card, matching the Figma reference dimension.
    private func frameSize(for orientation: WidgetTicketImageRef.Orientation) -> CGSize {
        switch orientation {
        case .vertical:
            return CGSize(
                width: Self.commonDim,
                height: Self.commonDim * (114.0 / 66.0)
            )
        case .horizontal:
            return CGSize(
                width: Self.commonDim * (115.0 / 66.0),
                height: Self.commonDim
            )
        }
    }

    private var featuredRefs: [WidgetTicketImageRef] {
        let wanted = featuredTicketIds.prefix(3)
        return wanted.compactMap { id in
            memory.ticketImageRefs.first(where: { $0.ticketId == id })
        }
    }

    // MARK: - Right section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            statRow(value: memory.categoryStyleRawValues.count, unit: "categories")
            Spacer()
            statRow(value: memory.kmTotal ?? 0, unit: "km")
            Spacer()
            statRow(value: memory.dayCount ?? 0, unit: memory.dayCount == 1 ? "day" : "days")
        }
        .padding(.vertical, 26)
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func statRow(value: Int, unit: String) -> some View {
        Text("\(value) \(unit)")
            .font(.system(size: 12, design: .rounded).weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
