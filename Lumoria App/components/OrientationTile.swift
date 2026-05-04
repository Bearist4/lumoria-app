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
    /// When false the tile is rendered as a plain preview card — no
    /// button wrapper, no selection chrome, no label. Used by the
    /// new-ticket form step to surface a static ticket preview at the
    /// top of the form.
    var isInteractive: Bool = true

    var body: some View {
        if isInteractive {
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
        } else {
            preview
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.Background.fieldFill)
                )
        }
    }

    // MARK: - Title

    private var title: String {
        if let titleOverride { return titleOverride }
        switch orientation {
        case .horizontal: return String(localized: "Landscape")
        case .vertical:   return String(localized: "Portrait")
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
