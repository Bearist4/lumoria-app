//
//  OrientationTile.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=978-14822
//
//  Pick-one tile used to choose whether the ticket is rendered horizontally
//  ("Landscape") or vertically ("Portrait"). Thumbnail is a small live
//  preview of the selected template in that orientation.
//

import SwiftUI

struct OrientationTile: View {

    let orientation: TicketOrientation
    /// Ticket payload used for the preview thumbnail.
    let previewPayload: TicketPayload
    var isSelected: Bool = false
    /// Defaults to "Landscape" / "Portrait"; override if the funnel needs
    /// different labels (e.g. localized strings).
    var titleOverride: String? = nil
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            SelectionTile(isSelected: isSelected, verticalPadding: 32) {
                VStack(spacing: 16) {
                    preview
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    SelectionTileLabel(text: title, isSelected: isSelected)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Title

    private var title: String {
        if let titleOverride { return titleOverride }
        switch orientation {
        case .horizontal: return "Landscape"
        case .vertical:   return "Portrait"
        }
    }

    // MARK: - Preview thumbnail

    /// Scales to the available space while keeping the template's own aspect
    /// ratio. Horizontal previews fit by width, vertical by height — the
    /// `aspectRatio(.fit)` inside each template view handles the rest.
    private var preview: some View {
        TicketPreview(
            ticket: Ticket(orientation: orientation, payload: previewPayload)
        )
    }
}

// MARK: - Preview

#Preview("Orientation tiles") {
    let payload: TicketPayload = TicketsStore.sampleTickets[2].payload
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            OrientationTile(orientation: .horizontal, previewPayload: payload)
            OrientationTile(orientation: .horizontal, previewPayload: payload, isSelected: true)
        }
        HStack(spacing: 16) {
            OrientationTile(orientation: .vertical, previewPayload: payload)
            OrientationTile(orientation: .vertical, previewPayload: payload, isSelected: true)
        }
    }
    .padding(24)
    .background(Color.Background.default)
}
