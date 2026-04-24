//
//  MiniTicketView.swift
//  Lumoria (widget)
//
//  Loads a pre-rendered ticket PNG out of the shared App Group container
//  and renders it with a soft shadow, matching the Figma card depth.
//

import SwiftUI

struct MiniTicketView: View {
    let ref: WidgetTicketImageRef

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
            } else {
                // Ghost card so the widget gallery / placeholder state
                // still shows 3 ticket-shaped rectangles that the system
                // can redact into grey bars.
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.12))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 0)
    }

    private func loadImage() -> UIImage? {
        guard let url = WidgetSharedContainer.ticketImageURL(filename: ref.filename) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
