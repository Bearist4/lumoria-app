//
//  WidgetFlowLayout.swift
//  Lumoria (widget)
//
//  Minimal centre-aligned flow layout for the small variant's category
//  icon grid. SwiftUI has no built-in flow, so this stamps a small one
//  using the Layout protocol.
//

import SwiftUI

struct WidgetFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = layout(in: maxWidth, subviews: subviews)
        let width = min(maxWidth, rows.map { $0.width }.max() ?? 0)
        let height = rows.reduce(0) { $0 + $1.height } +
            CGFloat(max(0, rows.count - 1)) * verticalSpacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = layout(in: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    // MARK: - Layout math

    private struct Row {
        var items: [(subview: LayoutSubview, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layout(in maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let spacing: CGFloat = rows[rows.count - 1].items.isEmpty ? 0 : horizontalSpacing
            if rows[rows.count - 1].width + spacing + size.width > maxWidth,
               !rows[rows.count - 1].items.isEmpty {
                rows.append(Row())
            }
            let rowIndex = rows.count - 1
            let rowSpacing: CGFloat = rows[rowIndex].items.isEmpty ? 0 : horizontalSpacing
            rows[rowIndex].items.append((subview, size))
            rows[rowIndex].width += rowSpacing + size.width
            rows[rowIndex].height = max(rows[rowIndex].height, size.height)
        }
        return rows
    }
}
