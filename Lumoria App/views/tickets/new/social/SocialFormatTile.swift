//
//  SocialFormatTile.swift
//  Lumoria App
//
//  Grid card used in `SocialView`. Shows a scaled-down render of the
//  ticket inside the target format's canvas, plus the platform label
//  (and icon, if any). Tap triggers the save flow in the parent view.
//  A loading overlay is shown while the parent is rendering this
//  format to a UIImage.
//

import SwiftUI

struct SocialFormatTile: View {

    let format: SocialFormat
    let ticket: Ticket
    let isLoading: Bool
    let action: () -> Void

    // Fixed preview-box dimensions from Figma FormatCard (1109:32533). Every
    // format renders into this 167×298 box via aspect-fit, so tiles stay
    // visually uniform regardless of canvas ratio.
    private let previewSize = CGSize(width: 167, height: 298)
    private let previewCorner: CGFloat = 14

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                preview
                label
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .frame(width: 199, height: 378.889)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.Background.elevated)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    @ViewBuilder
    private var preview: some View {
        // Aspect-fit the format canvas into the preview box.
        let widthScale  = previewSize.width  / format.canvasSize.width
        let heightScale = previewSize.height / format.canvasSize.height
        let scale       = min(widthScale, heightScale)

        ZStack {
            renderView
                .frame(width: format.canvasSize.width,
                       height: format.canvasSize.height)
                .scaleEffect(scale, anchor: .center)
                .frame(width: format.canvasSize.width * scale,
                       height: format.canvasSize.height * scale)
        }
        .frame(width: previewSize.width, height: previewSize.height)
        .clipShape(RoundedRectangle(cornerRadius: previewCorner, style: .continuous))
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.35)
                    ProgressView()
                        .tint(.white)
                        .controlSize(.large)
                }
                .clipShape(RoundedRectangle(cornerRadius: previewCorner, style: .continuous))
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }

    @ViewBuilder
    private var renderView: some View {
        switch format {
        case .square:    SquareRenderView(ticket: ticket)
        case .story:     StoryRenderView(ticket: ticket)
        case .facebook:  FacebookRenderView(ticket: ticket)
        case .instagram: InstagramRenderView(ticket: ticket)
        case .x:         XRenderView(ticket: ticket)
        }
    }

    @ViewBuilder
    private var label: some View {
        if let iconName = format.platformIconAssetName {
            HStack(spacing: 12) {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text(format.title)
                    .font(.headline)
                    .foregroundStyle(Color.Text.primary)
            }
        } else {
            Text(format.title)
                .font(.headline)
                .foregroundStyle(Color.Text.primary)
        }
    }
}

// MARK: - Preview

private var previewTicket: Ticket {
    TicketsStore.sampleTickets[0]
}

#Preview("All formats") {
    ScrollView {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
            ForEach(SocialFormat.allCases) { format in
                SocialFormatTile(
                    format: format,
                    ticket: previewTicket,
                    isLoading: false,
                    action: {}
                )
            }
        }
        .padding(16)
    }
    .background(Color.Background.default)
}

#Preview("Loading state") {
    SocialFormatTile(
        format: .story,
        ticket: previewTicket,
        isLoading: true,
        action: {}
    )
    .frame(width: 199)
    .padding()
    .background(Color.Background.default)
}
