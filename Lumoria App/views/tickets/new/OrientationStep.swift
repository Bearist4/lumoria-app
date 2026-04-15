//
//  OrientationStep.swift
//  Lumoria App
//
//  Step 3 — choose landscape vs portrait for the selected template.
//

import SwiftUI

struct NewTicketOrientationStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    var body: some View {
        VStack(spacing: 16) {
            OrientationTile(
                orientation: .horizontal,
                previewPayload: previewPayload,
                isSelected: funnel.orientation == .horizontal,
                onTap: { funnel.orientation = .horizontal }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            OrientationTile(
                orientation: .vertical,
                previewPayload: previewPayload,
                isSelected: funnel.orientation == .vertical,
                onTap: { funnel.orientation = .vertical }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewPayload: TicketPayload {
        NewTicketFunnel.previewPayload(for: funnel.template ?? .studio)
    }
}
