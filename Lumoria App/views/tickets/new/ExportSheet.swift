//
//  ExportSheet.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1109-31331 (destinations)
//          figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1357-119632 (camera roll)
//
//  Two-phase export modal. Phase A lists destinations (Social / IM locked,
//  Camera roll available). Phase B is the camera-roll configurator — preview
//  plus format/resolution/crop controls and an Export CTA that renders the
//  ticket into a UIImage and drops it in the user's photo library.
//
//  The two phases live inside the same sheet; the transition between them
//  is a horizontal slide rather than a nested sheet presentation.
//

import SwiftUI
import UIKit

// MARK: - Entry point

struct ExportSheet: View {

    let ticket: Ticket

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .destinations

    enum Phase { case destinations, cameraRoll }

    var body: some View {
        ZStack {
            switch phase {
            case .destinations:
                DestinationsView(
                    onClose: { dismiss() },
                    onCameraRoll: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            phase = .cameraRoll
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))
            case .cameraRoll:
                CameraRollView(
                    ticket: ticket,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            phase = .destinations
                        }
                    },
                    onExported: { dismiss() }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            }
        }
        .background(Color.Background.default)
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Phase A: destinations

private struct DestinationsView: View {

    let onClose: () -> Void
    let onCameraRoll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                LumoriaIconButton(systemImage: "xmark", action: onClose)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Text("Export your ticket")
                .font(.system(size: 34, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 16) {
                    destinationCard(
                        iconRow: AnyView(socialIconRow(.social)),
                        title: "Social Media",
                        subtitle: "Post your Lumoria ticket in your story or as a post.",
                        isEnabled: false,
                        action: {}
                    )
                    destinationCard(
                        iconRow: AnyView(socialIconRow(.messaging)),
                        title: "Instant messaging",
                        subtitle: "Share your Lumoria ticket with your friends.",
                        isEnabled: false,
                        action: {}
                    )
                    destinationCard(
                        iconRow: AnyView(cameraRollIcon()),
                        title: "Camera roll",
                        subtitle: "Save your Lumoria ticket in your gallery.",
                        isEnabled: true,
                        action: onCameraRoll
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Destination card

    private func destinationCard(
        iconRow: AnyView,
        title: String,
        subtitle: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                iconRow
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(-0.43)
                        .foregroundStyle(Color.Text.primary)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .tracking(-0.08)
                        .foregroundStyle(Color.Text.secondary)
                }
                if !isEnabled {
                    Text("Coming soon")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.Text.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.Background.elevated)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }

    // MARK: - Icon rows

    fileprivate enum SocialGroup {
        case social, messaging

        /// Asset catalog paths for each brand icon (under `export/`).
        var assetNames: [String] {
            switch self {
            case .social:
                return [
                    "export/social/IG",
                    "export/social/X",
                    "export/social/Threads",
                    "export/social/Snapchat",
                    "export/social/Facebook",
                ]
            case .messaging:
                return [
                    "export/IM/Whatsapp",
                    "export/IM/Messenger",
                    "export/IM/Discord",
                ]
            }
        }
    }

    @ViewBuilder
    private func socialIconRow(_ group: SocialGroup) -> some View {
        HStack(spacing: 12) {
            ForEach(group.assetNames, id: \.self) { name in
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
        }
    }

    @ViewBuilder
    private func cameraRollIcon() -> some View {
        Image("export/roll/Photos")
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
    }
}

// MARK: - Phase B: camera roll configurator

private struct CameraRollView: View {

    let ticket: Ticket
    let onBack: () -> Void
    let onExported: () -> Void

    @State private var includeBackground: Bool = true
    @State private var includeWatermark: Bool = true
    @State private var resolution: Resolution = .standard
    @State private var crop: Crop = .fullTicket
    @State private var format: Format = .png

    @State private var toastMessage: String? = nil
    @State private var isExporting: Bool = false

    enum Resolution: String, CaseIterable, Identifiable {
        case standard = "Standard", x2 = "2x", x3 = "3x"
        var id: String { rawValue }
        var scale: CGFloat {
            switch self { case .standard: 1; case .x2: 2; case .x3: 3 }
        }
    }
    enum Crop: String, CaseIterable, Identifiable {
        case fullTicket = "Full ticket", square = "Square"
        var id: String { rawValue }
    }
    enum Format: String, CaseIterable, Identifiable {
        case jpg = "JPG", png = "PNG"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 16) {
            toolbar

            ScrollView {
                VStack(spacing: 16) {
                    Text("Camera roll")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(Color.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    previewCard

                    Text("Export options")
                        .font(.system(size: 20, weight: .semibold))
                        .tracking(-0.45)
                        .foregroundStyle(Color.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    toggleRow(
                        title: "Background",
                        subtitle: "Your ticket, set against a beautiful scene.",
                        isOn: $includeBackground
                    )
                    toggleRow(
                        title: "Watermark",
                        subtitle: "Let people know where the magic came from.",
                        isOn: $includeWatermark
                    )
                    segmentedRow(
                        title: "Resolution",
                        subtitle: "Higher resolution means sharper prints and larger displays.",
                        selection: $resolution
                    )
                    segmentedRow(
                        title: "Crop",
                        subtitle: "Full ticket keeps every detail. Square fits any feed.",
                        selection: $crop
                    )
                    segmentedRow(
                        title: "Format",
                        subtitle: "PNG preserves every detail. JPG keeps things light.",
                        selection: $format
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .lumoriaToast($toastMessage)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            LumoriaIconButton(systemImage: "chevron.left", action: onBack)
            Spacer()
            Button(action: export) {
                Text(isExporting ? "Exporting…" : "Export")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.43)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Preview

    private var previewCard: some View {
        let previewTicket = ticket
        return VStack {
            TicketPreview(ticket: previewTicket)
                .aspectRatio(previewTicket.orientation == .horizontal ? 455/260 : 260/455, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(26)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.Background.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.Border.default, lineWidth: 1)
        )
    }

    // MARK: - Rows

    private func toggleRow(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.43)
                    .foregroundStyle(Color.Text.primary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .tracking(-0.08)
                    .foregroundStyle(Color.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.green)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Background.elevated)
        )
    }

    private func segmentedRow<T: Hashable & CaseIterable & Identifiable & RawRepresentable>(
        title: String,
        subtitle: String,
        selection: Binding<T>
    ) -> some View where T.RawValue == String, T.AllCases: RandomAccessCollection {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.43)
                    .foregroundStyle(Color.Text.primary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .tracking(-0.08)
                    .foregroundStyle(Color.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Picker(title, selection: selection) {
                ForEach(T.allCases) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Background.elevated)
        )
    }

    // MARK: - Export

    private func export() {
        isExporting = true
        Task { @MainActor in
            defer { isExporting = false }

            let rendered = renderImage()
            guard let image = rendered else {
                toastMessage = "Couldn't render ticket."
                return
            }

            // Apply format: JPEG/PNG. Re-decode so we hand the OS the right
            // codec — `UIImageWriteToSavedPhotosAlbum` saves whatever bytes
            // are wrapped in the UIImage, so compressing here matters.
            let finalImage: UIImage
            switch format {
            case .jpg:
                if let data = image.jpegData(compressionQuality: 0.95),
                   let img = UIImage(data: data) {
                    finalImage = img
                } else { finalImage = image }
            case .png:
                if let data = image.pngData(),
                   let img = UIImage(data: data) {
                    finalImage = img
                } else { finalImage = image }
            }

            UIImageWriteToSavedPhotosAlbum(finalImage, nil, nil, nil)
            toastMessage = "Saved to Camera roll"
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            onExported()
        }
    }

    /// Renders the configured ticket view to a `UIImage` at the chosen
    /// resolution + crop. Background/watermark toggles are honored at the
    /// view level before rendering.
    @MainActor
    private func renderImage() -> UIImage? {
        let exportView = ExportRenderView(
            ticket: ticket,
            includeBackground: includeBackground,
            includeWatermark: includeWatermark,
            crop: crop
        )
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = resolution.scale * UIScreen.main.scale
        return renderer.uiImage
    }
}

// MARK: - Render view

/// Off-screen composition used by the `ImageRenderer`. Keeps render logic
/// separate from the interactive preview so export settings don't affect
/// what the user sees on screen.
private struct ExportRenderView: View {
    let ticket: Ticket
    let includeBackground: Bool
    let includeWatermark: Bool
    let crop: CameraRollView.Crop

    private var canvasSize: CGSize {
        switch crop {
        case .fullTicket:
            return ticket.orientation == .horizontal
                ? CGSize(width: 1820, height: 1040)   // 455×260 × 4
                : CGSize(width: 1040, height: 1820)
        case .square:
            return CGSize(width: 1500, height: 1500)
        }
    }

    var body: some View {
        ZStack {
            if includeBackground {
                LinearGradient(
                    colors: [Color(hex: "F5D46A"), Color(hex: "F07AC0")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.clear
            }

            TicketPreview(ticket: ticket)
                .padding(64)

            if includeWatermark {
                VStack {
                    Spacer()
                    Text("Made with Lumoria")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.bottom, 24)
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }
}
