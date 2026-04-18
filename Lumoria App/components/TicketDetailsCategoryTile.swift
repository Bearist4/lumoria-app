//
//  TicketDetailsCategoryTile.swift
//  Lumoria App
//
//  Colored pill that tags a ticket by category — icon stacked above the
//  category name. Renders at its parent's width, so callers can drop it
//  in a 2-column grid (176pt) or stretch it to full width inside the
//  ticket-details card.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1652-57952
//

import SwiftUI

struct TicketDetailsCategoryTile: View {
    let category: TicketCategoryStyle

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: category.systemImage)
                .font(.body)
                .foregroundStyle(category.onColor)

            Text(category.displayName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(category.onColor)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(category.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview("Grid") {
    LazyVGrid(
        columns: [GridItem(.flexible()), GridItem(.flexible())],
        spacing: 16
    ) {
        ForEach(TicketCategoryStyle.allCases) { c in
            TicketDetailsCategoryTile(category: c)
        }
    }
    .padding(24)
    .background(Color.Background.default)
}

#Preview("Full width") {
    VStack(spacing: 12) {
        ForEach(TicketCategoryStyle.allCases) { c in
            TicketDetailsCategoryTile(category: c)
        }
    }
    .padding(24)
    .background(Color.Background.default)
}
