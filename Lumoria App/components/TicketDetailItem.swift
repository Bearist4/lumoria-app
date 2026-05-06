//
//  TicketDetailItem.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1016-22968
//

import SwiftUI

/// A single "ticket detail" pill — label + sublabel centered on a white
/// rounded container. Used inside `TicketDetailsCard`.
struct TicketDetailItem: View {

    let label: LocalizedStringKey
    let sublabel: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.subheadline.bold())
                .foregroundStyle(Color.Text.secondary)
                .lineLimit(1)

            Text(sublabel)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.Text.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Background.default)
     
        )
        

        
    }
}

// MARK: - Preview

#Preview("Ticket detail items") {
    VStack(spacing: 8) {
        HStack(spacing: 8) {
            TicketDetailItem(label: "Created", sublabel: "03 January 2025")
            TicketDetailItem(label: "Edited",  sublabel: "15 January 2025")
        }
        TicketDetailItem(label: "✈︎", sublabel: "Plane ticket")
    }
    .padding(24)
    .background(Color.Background.elevated)
}
