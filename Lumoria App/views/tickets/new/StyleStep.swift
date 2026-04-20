//
//  StyleStep.swift
//  Lumoria App
//
//  Step 5 — user picks a colorway (style variant) for the chosen
//  template. Only reached when `funnel.hasStylesStep` is true.
//

import SwiftUI

struct NewTicketStyleStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            previewCard
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 16) {
                Text("Available styles")
                    .font(.title2.bold())
                    .foregroundStyle(Color.Text.primary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(funnel.availableStyles) { variant in
                            StyleTile(
                                title: variant.label,
                                palette: variant.swatch,
                                isSelected: isSelected(variant),
                                onTap: { funnel.selectedStyleId = variant.id }
                            )
                            .frame(width: 189)
                        }
                    }
                }
            }
        }
        .onChange(of: funnel.selectedStyleId) { _, newValue in
            guard let newValue, let template = funnel.template else { return }
            Analytics.track(.ticketStyleSelected(
                template: template.analyticsTemplate,
                styleId: newValue
            ))
        }
    }

    /// A variant counts as selected when its id matches the funnel
    /// selection, OR when nothing is selected yet and it is the first
    /// (default) variant — keeps the picker visually anchored.
    private func isSelected(_ variant: TicketStyleVariant) -> Bool {
        if let id = funnel.selectedStyleId { return id == variant.id }
        return variant.id == funnel.template?.defaultStyle.id
    }

    // MARK: - Preview card

    @ViewBuilder
    private var previewCard: some View {
        if let payload = funnel.buildPayload() {
            let ticket = Ticket(
                orientation: funnel.orientation,
                payload: payload,
                styleId: funnel.selectedStyleId
            )
            ZStack {
                TicketPreview(ticket: ticket, isCentered: true)
                    .padding(funnel.orientation == .horizontal ? 16 : 64)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.Background.elevated)
            )
        }
    }
}
