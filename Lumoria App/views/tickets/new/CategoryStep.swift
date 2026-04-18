//
//  CategoryStep.swift
//  Lumoria App
//
//  Step 1 — user picks the ticket category. Only "Plane" is available today;
//  the other categories render in a disabled state until their templates ship.
//

import SwiftUI

struct NewTicketCategoryStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(TicketCategory.allCases) { category in
                CategoryTile(
                    title: category.title,
                    imageName: category.imageName,
                    isSelected: funnel.category == category,
                    isAvailable: category.isAvailable,
                    onTap: { funnel.category = category }
                )
            }
        }
        .onChange(of: funnel.category) { _, newValue in
            guard let newValue else { return }
            Analytics.track(.ticketCategorySelected(category: newValue.analyticsProp))
        }
    }
}
