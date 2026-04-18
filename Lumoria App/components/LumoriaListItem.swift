//
//  LumoriaListItem.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=390-4350
//

import SwiftUI

/// A horizontal list row with optional leading/trailing 56×56 slots and
/// a title + optional subtitle column.
struct LumoriaListItem<Left: View, Right: View>: View {

    let title: String
    var subtitle: String? = nil

    @ViewBuilder var leftItem: () -> Left
    @ViewBuilder var rightItem: () -> Right

    private let slotSize: CGFloat = 56

    var body: some View {
        HStack(spacing: 12) {
            leftItem()
                .frame(width: slotSize, height: slotSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.Text.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)

            rightItem()
                .frame(width: slotSize, height: slotSize)
        }
        .padding(8)
        .frame(minHeight: 64)
    }
}

// MARK: - Convenience inits (no slots)

extension LumoriaListItem where Left == EmptyView, Right == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(
            title: title,
            subtitle: subtitle,
            leftItem: { EmptyView() },
            rightItem: { EmptyView() }
        )
    }
}

extension LumoriaListItem where Right == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leftItem: @escaping () -> Left
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            leftItem: leftItem,
            rightItem: { EmptyView() }
        )
    }
}

extension LumoriaListItem where Left == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder rightItem: @escaping () -> Right
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            leftItem: { EmptyView() },
            rightItem: rightItem
        )
    }
}

// MARK: - Preview

#Preview("List items") {
    VStack(spacing: 0) {
        LumoriaListItem(title: "Label")

        LumoriaListItem(title: "Label", subtitle: "Secondary label")

        LumoriaListItem(
            title: "Settings",
            subtitle: "App preferences",
            leftItem: {
                Circle().fill(Color.Background.subtle)
                    .overlay {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.Text.secondary)
                    }
            }
        )

        LumoriaListItem(
            title: "Action",
            leftItem: {
                Circle().fill(Color.Background.subtle)
            },
            rightItem: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.Text.tertiary)
            }
        )
    }
    .frame(width: 408)
    .background(Color.Background.default)
}
