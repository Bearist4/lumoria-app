//
//  TicketDetailsCard.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1016-21315
//
//  Surface shown in the ticket-detail view that bundles "About this ticket"
//  metadata + a Collections section. The metadata row list is driven by an
//  array of `TicketDetailsCard.Item`; consecutive half-width items pair up
//  on one row, full-width items get their own row.
//

import SwiftUI

// MARK: - Item

/// A single label + sublabel row inside a `TicketDetailsCard`.
/// Lives at the top level so callers can build a single `[Item]` array and
/// pass it to any specialization of the generic card.
struct TicketDetailsCardItem: Identifiable {
    let id = UUID()
    let label: String
    let sublabel: String
    /// When `true` the item spans the full card width on its own row.
    var fullWidth: Bool = false
}

// MARK: - Card

struct TicketDetailsCard<CollectionsContent: View>: View {

    // MARK: Types

    typealias Item = TicketDetailsCardItem

    // MARK: Inputs

    var title: String = "About this ticket"
    let items: [Item]
    var collectionsTitle: String = "Collections"
    let menuItems: [LumoriaMenuItem]
    @ViewBuilder var collectionsContent: () -> CollectionsContent

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .tracking(0.38)
                .foregroundStyle(Color.Text.primary)

            itemsGrid

            collectionsSection
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.Background.elevated)
        )
    }

    // MARK: Item rows

    private var itemsGrid: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row) { item in
                        TicketDetailItem(label: item.label, sublabel: item.sublabel)
                    }
                }
            }
        }
    }

    /// Groups consecutive half-width items into pairs; full-width items get
    /// their own row.
    private var rows: [[Item]] {
        var out: [[Item]] = []
        var pair: [Item] = []
        for item in items {
            if item.fullWidth {
                if !pair.isEmpty { out.append(pair); pair = [] }
                out.append([item])
            } else {
                pair.append(item)
                if pair.count == 2 { out.append(pair); pair = [] }
            }
        }
        if !pair.isEmpty { out.append(pair) }
        return out
    }

    // MARK: Collections section

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(collectionsTitle)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.26)
                    .foregroundStyle(Color.Text.primary)

                Spacer(minLength: 0)

                LumoriaContextualMenuButton(items: menuItems) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.Text.primary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle().fill(Color.black.opacity(0.05))
                        )
                }
            }

            collectionsContent()
        }
    }
}

// MARK: - Preview

#Preview("No collection") {
    TicketDetailsCard(
        items: [
            .init(label: "Creation",  sublabel: "03 January 2025"),
            .init(label: "Last edit", sublabel: "15 January 2025"),
            .init(label: "✈︎", sublabel: "Plane ticket", fullWidth: true),
        ],
        menuItems: [
            .init(title: "Create collection…", action: {}),
        ],
        collectionsContent: {
            Text("You have no collection yet. To create a collection, tap the + icon.")
                .font(.system(size: 15, weight: .regular))
                .tracking(-0.23)
                .foregroundStyle(Color.Text.secondary)
        }
    )
    .frame(width: 408)
    .padding(24)
    .background(Color.Background.default)
}

#Preview("With collection cards") {
    TicketDetailsCard(
        items: [
            .init(label: "Creation",  sublabel: "03 January 2025"),
            .init(label: "Last edit", sublabel: "15 January 2025"),
            .init(label: "✈︎", sublabel: "Plane ticket", fullWidth: true),
        ],
        menuItems: [
            .init(title: "Create collection…", action: {}),
            .init(title: "Add to a collection…", action: {}),
            .init(title: "Remove from collection…", kind: .destructive, action: {}),
        ],
        collectionsContent: {
            HStack(spacing: 16) {
                CollectionCard(
                    title: "Japan 2026",
                    subtitle: "2 tickets",
                    state: .normal,
                    filledCount: 2,
                    colorFamily: "Blue"
                )
                CollectionCard(
                    title: "Family",
                    subtitle: "4 tickets",
                    state: .normal,
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
