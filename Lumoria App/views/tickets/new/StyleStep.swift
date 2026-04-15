//
//  StyleStep.swift
//  Lumoria App
//
//  Step 5 — user picks a colorway for the chosen template. Only reached when
//  `funnel.hasStylesStep` is true (see `NewTicketFunnel.styles(for:)`).
//

import SwiftUI

struct NewTicketStyleStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            previewCard

            Text("Available styles")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.26)
                .foregroundStyle(Color.Text.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(funnel.availableStyles.enumerated()), id: \.offset) { idx, palette in
                        StyleTile(
                            title: "Style \(idx + 1)",
                            palette: palette,
                            isSelected: funnel.styleIndex == idx,
                            onTap: { funnel.styleIndex = idx }
                        )
                        .frame(width: 189)
                    }
                }
            }
        }
    }

    // MARK: - Preview card

    @ViewBuilder
    private var previewCard: some View {
        if let payload = funnel.buildPayload() {
            let ticket = Ticket(orientation: funnel.orientation, payload: payload)
            TicketPreview(ticket: ticket)
                .padding(funnel.orientation == .horizontal ? 16 : 64)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.Background.elevated)
                )
        }
    }
}
