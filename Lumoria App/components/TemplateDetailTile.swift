//
//  TemplateDetailTile.swift
//  Lumoria App
//
//  Small tile used in the template-details sheet to call out each
//  piece of information the user needs to fill in ("airport codes",
//  "passenger details", etc). A 32pt centred SF Symbol over a
//  subheadline label, packed into a rounded `Background.subtle`
//  card with 12pt padding and a 150pt minimum width so a two-column
//  grid reflows neatly on narrower devices.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1876-44984
//

import SwiftUI

struct TemplateDetailTile: View {
    let systemImage: String
    let label: String

    init(systemImage: String, label: String) {
        self.systemImage = systemImage
        self.label = label
    }

    init(_ requirement: TemplateRequirement) {
        self.systemImage = requirement.systemImage
        self.label = requirement.label
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.Text.primary)
                .frame(width: 32, height: 32)

            Text(LocalizedStringKey(label))
                .font(.subheadline)
                .foregroundStyle(Color.Text.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .frame(minWidth: 150)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Background.subtle)
        )
    }
}

// MARK: - Preview

#Preview {
    let columns = [
        GridItem(.flexible(minimum: 150), spacing: 12),
        GridItem(.flexible(minimum: 150), spacing: 12),
    ]
    LazyVGrid(columns: columns, spacing: 12) {
        TemplateDetailTile(systemImage: "airplane",            label: "Airport codes")
        TemplateDetailTile(systemImage: "calendar.badge.clock", label: "Date & time of travel")
        TemplateDetailTile(systemImage: "airplane.departure",  label: "Flight details")
        TemplateDetailTile(systemImage: "person.text.rectangle", label: "Passenger details")
    }
    .padding(16)
}
