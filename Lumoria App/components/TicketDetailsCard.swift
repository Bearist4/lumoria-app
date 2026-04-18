//
//  TicketDetailsCard.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1016-21315
//
//  Surface shown in the ticket-detail view. Stacks:
//    • Title ("About this ticket")
//    • Creation + Last edit — two half-width metadata cards
//    • Category tile — full-width colored pill for the ticket's category
//    • Location card (optional) — compact map with a white pill labeling
//      the primary location at the bottom
//    • Memories section — header + overflow menu + caller-supplied content
//

import MapKit
import SwiftUI

// MARK: - Card

struct TicketDetailsCard<MemoriesContent: View>: View {

    // MARK: Inputs

    var title: LocalizedStringKey = "About this ticket"
    let creationDate: String
    let lastEditDate: String
    let category: TicketCategoryStyle
    /// Primary location of the ticket. Hidden when nil.
    let location: TicketLocation?
    var memoriesTitle: LocalizedStringKey = "Memories"
    let menuItems: [LumoriaMenuItem]
    @ViewBuilder var memoriesContent: () -> MemoriesContent

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title.bold())
                .foregroundStyle(Color.Text.primary)

            metadataRow
            categoryRow
            if let location { locationCard(location) }
            memoriesSection
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.Background.elevated)
        )
    }

    // MARK: Metadata row

    private var metadataRow: some View {
        HStack(spacing: 8) {
            TicketDetailItem(label: "Created on",  sublabel: creationDate)
            TicketDetailItem(label: "Last edited", sublabel: lastEditDate)
        }
    }

    // MARK: Category tile

    private var categoryRow: some View {
        TicketDetailsCategoryTile(category: category)
    }

    // MARK: Location card

    private func locationCard(_ location: TicketLocation) -> some View {
        ZStack(alignment: .bottom) {
            Map(
                initialPosition: .region(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(
                        latitudeDelta: 0.08,
                        longitudeDelta: 0.08
                    )
                )),
                interactionModes: []
            )
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .all))
            .allowsHitTesting(false)

            locationNamePill(location)
                .padding(8)
        }
        .frame(height: 141)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func locationNamePill(_ location: TicketLocation) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: "📍")
                .font(.footnote)
            Text(locationPillLabel(location))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.Text.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.Background.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func locationPillLabel(_ location: TicketLocation) -> String {
        if let subtitle = location.subtitle, !subtitle.isEmpty {
            return "\(subtitle) · \(location.name)"
        }
        return location.name
    }

    // MARK: Memories section

    private var memoriesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(memoriesTitle)
                    .font(.title2.bold())
                    .foregroundStyle(Color.Text.primary)

                Spacer(minLength: 0)

                LumoriaContextualMenuButton(items: menuItems) {
                    Image(systemName: "ellipsis")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.Text.primary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle().fill(Color.Background.fieldFill)
                        )
                }
            }

            memoriesContent()
        }
    }
}

// MARK: - Preview

#Preview("No memory, with location") {
    TicketDetailsCard(
        creationDate: "03 January 2025",
        lastEditDate: "15 January 2025",
        category: .plane,
        location: TicketLocation(
            name: "Tokyo Narita",
            subtitle: "NRT",
            city: "Tokyo",
            country: "Japan",
            countryCode: "JP",
            lat: 35.7720,
            lng: 140.3929,
            kind: .airport
        ),
        menuItems: [
            .init(title: "Create memory…", action: {}),
        ],
        memoriesContent: {
            Text(verbatim: "You have no memories yet. To create a memory, tap the + icon.")
                .font(.subheadline)
                .foregroundStyle(Color.Text.secondary)
        }
    )
    .frame(width: 408)
    .padding(24)
    .background(Color.Background.default)
}

#Preview("With memory cards") {
    TicketDetailsCard(
        creationDate: "03 January 2025",
        lastEditDate: "15 January 2025",
        category: .plane,
        location: nil,
        menuItems: [
            .init(title: "Create memory…", action: {}),
            .init(title: "Add to a memory…", action: {}),
            .init(title: "Remove from memory…", kind: .destructive, action: {}),
        ],
        memoriesContent: {
            HStack(spacing: 16) {
                MemoryCard(
                    title: "Japan 2026",
                    subtitle: "2 tickets",
                    state: .normal,
                    emoji: "🗾",
                    filledCount: 2,
                    colorFamily: "Blue"
                )
                MemoryCard(
                    title: "Family",
                    subtitle: "4 tickets",
                    state: .normal,
                    emoji: "❤️",
                    filledCount: 3,
                    colorFamily: "Pink"
                )
            }
        }
    )
    .frame(width: 408)
    .padding(24)
    .background(Color.Background.default)
}
