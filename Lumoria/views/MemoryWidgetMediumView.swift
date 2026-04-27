//
//  MemoryWidgetMediumView.swift
//  Lumoria (widget)
//
//  349 × 164 variant — memory header and 3 tilted ticket minis on the
//  left, stats (km / days / category icon grid) on the right. Background
//  is the user's ticket-shaped art drawn by `MemoryWidgetEntryView`.
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
        HStack(spacing: 0) {
            leftSection
                .frame(maxWidth: .infinity)

            statsSection
                .frame(width: 108)
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

            appIconBadge
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
    }

    private var appIconBadge: some View {
        Group {
            if let image = loadBrandLogomark() {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 7.2, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.988, blue: 0.941))
            }
        }
        .frame(width: 24, height: 24)
    }

    private func loadBrandLogomark() -> UIImage? {
        guard let url = WidgetSharedContainer.brandLogomarkURL else { return nil }
        return UIImage(contentsOfFile: url.path)
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
                    .offset(x: slotOffsets[0], y: yOffset(for: ref.orientation))
            }
            if count > 1 {
                let ref = refs[1]
                let size = frameSize(for: ref.orientation)
                MiniTicketView(ref: ref)
                    .frame(width: size.width, height: size.height)
                    .rotationEffect(.degrees(slotAngles[1]))
                    .offset(x: slotOffsets[1], y: yOffset(for: ref.orientation))
            }
            if count > 2 {
                let ref = refs[2]
                let size = frameSize(for: ref.orientation)
                MiniTicketView(ref: ref)
                    .frame(width: size.width, height: size.height)
                    .rotationEffect(.degrees(slotAngles[2]))
                    .offset(x: slotOffsets[2], y: yOffset(for: ref.orientation))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .bottom)
    }

    /// Vertical tickets stand taller than horizontal ones, so with
    /// bottoms aligned they reach further up and clash with the memory
    /// header. Nudge verticals down 12pt to clear the title.
    private func yOffset(for orientation: WidgetTicketImageRef.Orientation) -> CGFloat {
        switch orientation {
        case .vertical:   return Self.bottomShift + 24
        case .horizontal: return Self.bottomShift
        }
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
            statText(formattedDistance(km: memory.kmTotal ?? 0))
                .padding(.top, 19)
                .padding(.leading, 16)

            statText("\(memory.dayCount ?? 0) \(memory.dayCount == 1 ? "day" : "days")")
                .padding(.top, 16)
                .padding(.leading, 16)

            Spacer(minLength: 0)

            WidgetFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(memory.categoryStyleRawValues, id: \.self) { rawValue in
                    Image(systemName: WidgetCategoryIcon.systemImage(for: rawValue))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func statText(_ string: String) -> some View {
        Text(string)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    /// Formats the journey's total distance using the user's
    /// `map.distanceUnit` pick (App Group default written by Settings).
    /// Defaults to kilometres when nothing has been chosen.
    private func formattedDistance(km: Int) -> String {
        let raw = WidgetSharedContainer.sharedDefaults
            .string(forKey: WidgetSharedContainer.DefaultsKey.distanceUnit) ?? "km"
        if raw == "mi" {
            let miles = Int((Double(km) * 0.621371).rounded())
            return "\(miles) mi."
        }
        return "\(km) km."
    }
}
