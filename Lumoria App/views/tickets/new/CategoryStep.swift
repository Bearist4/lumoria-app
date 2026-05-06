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
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(TicketCategory.allCases.filter(\.isAvailable)) { category in
                let tile = CategoryTile(
                    title: category.title,
                    emoji: category.emoji,
                    isSelected: funnel.category == category,
                    isAvailable: category.isAvailable,
                    onTap: { funnel.category = category }
                )
                if category == .plane {
                    tile.onboardingAnchor("funnel.categories")
                } else {
                    tile
                }
            }
        }
        .onAppear {
            if onboardingCoordinator.currentStep == .enterMemory {
                Task { await onboardingCoordinator.advance(from: .enterMemory) }
            }
        }
        .onChange(of: funnel.category) { _, newValue in
            guard let newValue else { return }
            Analytics.track(.ticketCategorySelected(category: newValue.analyticsProp))
            if onboardingCoordinator.currentStep == .pickCategory {
                Task { await onboardingCoordinator.advance(from: .pickCategory) }
            }
        }
    }
}
