//
//  SocialView.swift
//  Lumoria App
//
//  Phase C of `ExportSheet`: grid of social format tiles. Tap a tile
//  to render the ticket for that format and save it to the photo
//  library. The sheet dismisses ~1.2s after a successful save.
//
//  Figma: 1109:31332
//

import SwiftUI
import UIKit

struct SocialView: View {

    let ticket: Ticket
    let onBack: () -> Void
    let onExported: () -> Void

    @State private var saving: SocialFormat? = nil
    @State private var toastMessage: String? = nil

    private let columns = [GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Social Media")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.Text.primary)
                        .padding(.top, 8)

                    section(
                        title: "Default formats",
                        formats: SocialFormat.allCases.filter { $0.section == .defaultFormats }
                    )

                    section(
                        title: "Vertical",
                        formats: SocialFormat.allCases.filter { $0.section == .vertical }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .lumoriaToast($toastMessage)
    }

    private var toolbar: some View {
        HStack {
            LumoriaIconButton(systemImage: "chevron.left", action: onBack)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func section(title: LocalizedStringKey, formats: [SocialFormat]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Color.Text.primary)
                .padding(.top, 4)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(formats) { format in
                    SocialFormatTile(
                        format: format,
                        ticket: ticket,
                        isLoading: saving == format,
                        action: { Task { await save(format) } }
                    )
                }
            }
        }
    }

    @MainActor
    private func save(_ format: SocialFormat) async {
        guard saving == nil else { return }
        saving = format
        defer { saving = nil }

        Analytics.track(.exportDestinationSelected(destination: format.analyticsDestination))

        let start = Date()
        // Lumiere posters live in `MoviePosterImageCache` — pre-warm
        // before the snapshot so the rendered image isn't blank.
        if case .lumiere(let payload) = ticket.payload,
           !payload.posterUrl.isEmpty,
           let url = URL(string: payload.posterUrl) {
            await MoviePosterImageCache.shared.load(from: url)
        }
        let renderer = ImageRenderer(content: renderView(for: format))
        renderer.scale = UIScreen.main.scale
        renderer.isOpaque = true

        guard let image = renderer.uiImage else {
            toastMessage = String(localized: "Couldn't render ticket.")
            Analytics.track(.ticketExportFailed(
                destination: format.analyticsDestination,
                errorType: "render_failed"
            ))
            return
        }

        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        Analytics.track(.ticketExported(
            destination: format.analyticsDestination,
            resolution: nil, crop: nil, format: .png,
            includeBackground: nil, includeWatermark: nil,
            durationMs: durationMs
        ))
        Analytics.updateUserProperties([
            "last_export_destination": format.analyticsDestination.rawValue
        ])

        toastMessage = String(localized: "Saved to Camera roll")
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        onExported()
    }

    @ViewBuilder
    private func renderView(for format: SocialFormat) -> some View {
        switch format {
        case .square:    SquareRenderView(ticket: ticket)
        case .story:     StoryRenderView(ticket: ticket)
        case .facebook:  FacebookRenderView(ticket: ticket)
        case .instagram: InstagramRenderView(ticket: ticket)
        case .x:         XRenderView(ticket: ticket)
        }
    }
}

// MARK: - Preview

private var previewTicket: Ticket {
    TicketsStore.sampleTickets[0]
}

#Preview("Social view") {
    SocialView(
        ticket: previewTicket,
        onBack: {},
        onExported: {}
    )
    .background(Color.Background.default)
}
