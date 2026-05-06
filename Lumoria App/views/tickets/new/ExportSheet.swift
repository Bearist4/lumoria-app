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
    /// Fired right before this sheet self-dismisses on a successful
    /// export. Used by the parent (e.g. `NewTicketSuccessStep`) to
    /// dismiss the surrounding funnel and conclude the onboarding so
    /// the user lands back on Memories instead of the success screen.
    var onCompleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @Environment(EntitlementStore.self) private var entitlement
    @State private var phase: Phase = .destinations

    // IM share state
    @State private var isPreparingIMShare = false

    enum Phase { case destinations, cameraRoll, social }

    var body: some View {
        ZStack {
            switch phase {
            case .destinations:
                DestinationsView(
                    isPreparingIMShare: isPreparingIMShare,
                    onClose: { dismiss() },
                    onCameraRoll: {
                        Analytics.track(.exportDestinationSelected(destination: .camera_roll))
                        withAnimation(.easeInOut(duration: 0.25)) {
                            phase = .cameraRoll
                        }
                    },
                    onInstantMessaging: {
                        Analytics.track(.exportDestinationSelected(destination: .whatsapp))
                        Task { await handleIMShare() }
                    },
                    onSocial: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            phase = .social
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
                    onExported: {
                        onCompleted?()
                        dismiss()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            case .social:
                SocialView(
                    ticket: ticket,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            phase = .destinations
                        }
                    },
                    onExported: {
                        onCompleted?()
                        dismiss()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            }
        }
        .background(Color.Background.default)
        .presentationDragIndicator(.visible)
        .onAppear {
            Analytics.track(.exportSheetOpened(
                category: ticket.kind.analyticsCategory,
                template: ticket.kind.analyticsTemplate
            ))
        }
        .onboardingOverlay(
            step: .exportOrAddMemory,
            coordinator: onboardingCoordinator,
            anchorID: "export.cameraRoll",
            tip: OnboardingTipCopy(
                title: "Save to camera roll",
                body: "Tap Camera roll to save your ticket as an image in your photo library."
            )
        )
    }

    // MARK: - IM share

    /// Activity types hidden from the IM share sheet. Camera roll already has
    /// its own dedicated flow; the rest are either irrelevant or sunset/obscure
    /// social networks.
    private static let excludedIMActivityTypes: [UIActivity.ActivityType] = [
        .saveToCameraRoll,
        .addToReadingList,
        .assignToContact,
        .openInIBooks,
        .markupAsPDF,
        .postToFacebook,
        .postToTwitter,
        .postToWeibo,
        .postToFlickr,
        .postToVimeo,
        .postToTencentWeibo,
    ]

    @MainActor
    private func handleIMShare() async {
        guard !isPreparingIMShare else { return }
        isPreparingIMShare = true
        defer { isPreparingIMShare = false }

        await prewarmRemoteAssets(for: ticket)
        let renderer = ImageRenderer(content: IMShareRenderView(ticket: ticket))
        renderer.scale = 2.0
        renderer.isOpaque = true  // skip alpha — render is fully opaque
        guard let image = renderer.uiImage else { return }

        presentActivityController(for: image)
    }


    /// Presents the activity sheet via UIKit on the topmost presented view
    /// controller. SwiftUI's `.sheet` cannot host a `UIActivityViewController`
    /// when the parent view is itself presented in a sheet — iOS fights over
    /// the presentation slot and the activity items silently fail to register
    /// with their target activities (classic "SHSheetActivityPerformer
    /// already performing" log).
    @MainActor
    private func presentActivityController(for image: UIImage) {
        guard
            let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive })
                as? UIWindowScene,
            let window = scene.windows.first(where: \.isKeyWindow),
            let rootVC = window.rootViewController
        else { return }

        var topVC: UIViewController = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let controller = UIActivityViewController(
            activityItems: [image, LumoriaLinks.shareMessage],
            applicationActivities: nil
        )
        controller.excludedActivityTypes = Self.excludedIMActivityTypes
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            guard completed else { return }
            let platform: IMPlatformProp = {
                let raw = activityType?.rawValue.lowercased() ?? ""
                if raw.contains("whatsapp") { return .whatsapp }
                if raw.contains("messenger") || raw.contains("fb-messenger") { return .messenger }
                if raw.contains("discord") { return .discord }
                return .other
            }()
            Analytics.track(.ticketSharedViaIM(platform: platform))
            let destination: ExportDestinationProp = {
                switch platform {
                case .whatsapp:  return .whatsapp
                case .messenger: return .messenger
                case .discord:   return .discord
                case .other:     return .whatsapp
                }
            }()
            Analytics.track(.ticketExported(
                destination: destination,
                resolution: nil, crop: nil, format: nil,
                includeBackground: nil, includeWatermark: nil,
                durationMs: 0
            ))
            Analytics.updateUserProperties(["last_export_destination": destination.rawValue])
        }

        // iPad popover anchor — no-op on iPhone.
        if let popover = controller.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX,
                y: topVC.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }

        topVC.present(controller, animated: true)
    }
}

// MARK: - Phase A: destinations

private struct DestinationsView: View {

    let isPreparingIMShare: Bool
    let onClose: () -> Void
    let onCameraRoll: () -> Void
    let onInstantMessaging: () -> Void
    let onSocial: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                LumoriaIconButton(systemImage: "xmark", action: onClose)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Text("Export your ticket")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 16) {
                    destinationCard(
                        iconRow: AnyView(socialIconRow(.social)),
                        title: "Social Media",
                        subtitle: "Post your Lumoria ticket in your story or as a post.",
                        isEnabled: true,
                        isComingSoon: false,
                        action: onSocial
                    )
                    destinationCard(
                        iconRow: AnyView(socialIconRow(.messaging)),
                        title: "Instant messaging",
                        subtitle: "Share your Lumoria ticket with your friends.",
                        isEnabled: !isPreparingIMShare,
                        isComingSoon: false,
                        isLoading: isPreparingIMShare,
                        action: onInstantMessaging
                    )
                    destinationCard(
                        iconRow: AnyView(cameraRollIcon()),
                        title: "Camera roll",
                        subtitle: "Save your Lumoria ticket in your gallery.",
                        isEnabled: true,
                        isComingSoon: false,
                        action: onCameraRoll
                    )
                    .onboardingAnchor("export.cameraRoll")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Destination card

    private func destinationCard(
        iconRow: AnyView,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        isEnabled: Bool,
        isComingSoon: Bool,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                iconRow
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.Text.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.Text.secondary)
                }
                if isComingSoon {
                    Text("Coming soon")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.Text.tertiary)
                } else if isLoading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Preparing…")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.Text.tertiary)
                    }
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

    @Environment(EntitlementStore.self) private var entitlement

    @State private var includeBackground: Bool = true
    @State private var backgroundStyle: ExportBackgroundStyle = .gradient
    @State private var includeWatermark: Bool = true
    @State private var resolution: Resolution = .standard
    @State private var crop: Crop = .fullTicket
    @State private var format: Format = .png

    @State private var toastMessage: String? = nil
    @State private var isExporting: Bool = false
    /// Drives the early-adopter promo from any of the gated export
    /// controls (Watermark off, 2x / 3x resolution, JPG format).
    @State private var showEarlyAdopterPromo: Bool = false

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
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    previewCard

                    Text("Export options")
                        .font(.title3.bold())
                        .foregroundStyle(Color.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    toggleRow(
                        title: "Background",
                        subtitle: "Your ticket, set against a beautiful scene.",
                        isOn: $includeBackground
                    )
                    if includeBackground {
                        backgroundStyleRow
                    }
                    toggleRow(
                        title: "Watermark",
                        subtitle: "Let people know where the magic came from.",
                        isOn: $includeWatermark,
                        proBadge: true
                    )
                    segmentedRow(
                        title: "Resolution",
                        subtitle: "Higher resolution means sharper prints and larger displays.",
                        selection: $resolution,
                        proBadge: true
                    )
                    segmentedRow(
                        title: "Crop",
                        subtitle: "Full ticket keeps every detail. Square fits any feed.",
                        selection: $crop
                    )
                    segmentedRow(
                        title: "Format",
                        subtitle: "PNG preserves every detail. JPG keeps things light.",
                        selection: $format,
                        proBadge: true
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .lumoriaToast($toastMessage)
        .sheet(isPresented: $showEarlyAdopterPromo) {
            EarlyAdopterPromoSheet()
                .environment(entitlement)
        }
        // Early-adopter gates on the camera-roll exporter. Defaults
        // (watermark on, Standard / 1x, PNG) stay free; flipping any
        // of them off the default reverts the choice and fires the
        // promo sheet for non-adopters.
        .onChange(of: includeWatermark) { _, newValue in
            if !newValue, !entitlement.isEarlyAdopter {
                includeWatermark = true
                showEarlyAdopterPromo = true
            }
        }
        .onChange(of: resolution) { _, newValue in
            if newValue != .standard, !entitlement.isEarlyAdopter {
                resolution = .standard
                showEarlyAdopterPromo = true
            }
        }
        .onChange(of: format) { _, newValue in
            if newValue != .png, !entitlement.isEarlyAdopter {
                format = .png
                showEarlyAdopterPromo = true
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            LumoriaIconButton(systemImage: "chevron.left", action: onBack)
            Spacer()
            Button(action: export) {
                Text(isExporting ? "Exporting…" : "Export")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.Button.Primary.Label.default)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.Button.Primary.Background.default)
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
        let isVertical = previewTicket.orientation == .vertical

        return ZStack {
            // Card backdrop: either the selected export background, or a
            // soft checkered pattern that stands in for the transparent
            // canvas the user is about to render.
            Group {
                if includeBackground {
                    ExportBackgroundView(style: backgroundStyle)
                } else {
                    CheckeredBackgroundView()
                }
            }

            TicketPreview(ticket: previewTicket, isCentered: true)
                .aspectRatio(isVertical ? 260/455 : 455/260, contentMode: .fit)
                // Vertical tickets cap at 200pt wide to mirror the 0.5×
                // downscale applied in `ExportRenderView` — real frame
                // constraint (not scaleEffect) so the card hugs the ticket
                // instead of reserving full-size space around it.
                .frame(maxWidth: isVertical ? 200 : .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, 26)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.Border.default, lineWidth: 1)
        )
        // Mirror the watermark toggle into the on-screen preview so the
        // user sees what the exported image will contain.
        .environment(\.showsLumoriaWatermark, includeWatermark)
    }

    // MARK: - Rows

    private var backgroundStyleRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Background style")
                    .font(.headline)
                    .foregroundStyle(Color.Text.primary)
                Text("Pick the scene your ticket is set against.")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                ForEach(ExportBackgroundStyle.allCases) { style in
                    BackgroundStyleTile(
                        style: style,
                        isSelected: backgroundStyle == style
                    ) {
                        backgroundStyle = style
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Background.elevated)
        )
    }

    private func toggleRow(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        isOn: Binding<Bool>,
        proBadge: Bool = false
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    if proBadge {
                        LumoriaPremiumBadge(style: .crown)
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.Text.primary)
                }
                Text(subtitle)
                    .font(.footnote)
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
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        selection: Binding<T>,
        proBadge: Bool = false
    ) -> some View where T.RawValue == String, T.AllCases: RandomAccessCollection {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    if proBadge {
                        LumoriaPremiumBadge(style: .crown)
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.Text.primary)
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Picker(title, selection: selection) {
                ForEach(T.allCases) { value in
                    // LocalizedStringKey created at runtime — catalog keys
                    // for translatable raw values ("Standard", "Full ticket",
                    // "Square") are added to Localizable.xcstrings manually
                    // since Xcode can't statically extract them from here.
                    Text(LocalizedStringKey(value.rawValue)).tag(value)
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
        let resolutionProp: ExportResolutionProp = {
            switch resolution {
            case .standard: return .x1
            case .x2:       return .x2
            case .x3:       return .x3
            }
        }()
        let cropProp: ExportCropProp = crop == .square ? .square : .full
        let formatProp: ExportFormatProp = format == .jpg ? .jpg : .png
        Analytics.track(.cameraRollExportConfigured(
            includeBackground: includeBackground,
            includeWatermark: includeWatermark,
            resolution: resolutionProp,
            crop: cropProp,
            format: formatProp
        ))
        let startedAt = Date()
        Task { @MainActor in
            defer { isExporting = false }

            await prewarmRemoteAssets(for: ticket)
            let rendered = renderImage()
            guard let image = rendered else {
                toastMessage = String(localized: "Couldn't render ticket.")
                Analytics.track(.ticketExportFailed(
                    destination: .camera_roll,
                    errorType: "render_failed"
                ))
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
            let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            Analytics.track(.ticketExported(
                destination: .camera_roll,
                resolution: resolutionProp,
                crop: cropProp,
                format: formatProp,
                includeBackground: includeBackground,
                includeWatermark: includeWatermark,
                durationMs: durationMs
            ))
            Analytics.updateUserProperties(["last_export_destination": ExportDestinationProp.camera_roll.rawValue])
            toastMessage = String(localized: "Saved to Camera roll")
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
            backgroundStyle: backgroundStyle,
            includeWatermark: includeWatermark,
            crop: crop
        )
        let renderer = ImageRenderer(content: exportView)
        renderer.scale = resolution.scale * UIScreen.main.scale
        // Preserve transparency when the user opted out of a background —
        // only PNG actually carries the alpha channel through.
        renderer.isOpaque = includeBackground
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
    let backgroundStyle: ExportBackgroundStyle
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
                ExportBackgroundView(style: backgroundStyle)
            } else {
                Color.clear
            }

            TicketPreview(ticket: ticket)
                .padding(64)
                // Vertical tickets render too large inside the portrait
                // canvas — scale them down so they sit comfortably in the
                // exported image with breathing room on all sides.
                .scaleEffect(ticket.orientation == .vertical ? 0.5 : 1.0)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        // Propagates down to every template view's `madeWithBadge` so they
        // render (or skip) the embedded Lumoria watermark in unison.
        .environment(\.showsLumoriaWatermark, includeWatermark)
    }
}

// MARK: - Remote-asset prewarm

/// Templates that pull artwork from the network at render time
/// (today: Lumiere's OMDb poster) need that artwork in the
/// synchronous image cache before `ImageRenderer.uiImage` is called
/// — `AsyncImage` doesn't load inside a snapshot. Awaits the load,
/// then returns; subsequent `Image(uiImage:)` reads in the template
/// view hit the cache. File-scope so both `ExportSheet`'s share path
/// and `CameraRollView`'s render path can call it.
@MainActor
func prewarmRemoteAssets(for ticket: Ticket) async {
    guard case .lumiere(let payload) = ticket.payload,
          !payload.posterUrl.isEmpty,
          let url = URL(string: payload.posterUrl) else { return }
    await MoviePosterImageCache.shared.load(from: url)
}

// MARK: - Background style

enum ExportBackgroundStyle: String, CaseIterable, Identifiable {
    case grid
    case gradient
    case white

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .grid:     return "Grid"
        case .gradient: return "Gradient"
        case .white:    return "White"
        }
    }
}

/// Renders the chosen export background at whatever size it's placed in.
struct ExportBackgroundView: View {
    let style: ExportBackgroundStyle

    var body: some View {
        switch style {
        case .grid:
            GridBackgroundView()
        case .gradient:
            LinearGradient(
                colors: [Color(hex: "F5D46A"), Color(hex: "F07AC0")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .white:
            Color.white
        }
    }
}

/// Soft architectural grid — thin gray lines on an off-white ground.
private struct GridBackgroundView: View {
    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = max(40, min(size.width, size.height) / 14)
            let lineColor = Color.black.opacity(0.08)
            var x: CGFloat = 0
            while x <= size.width {
                ctx.fill(
                    Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
                    with: .color(lineColor)
                )
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                ctx.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(lineColor)
                )
                y += spacing
            }
        }
        .background(Color(hex: "F7F5EF"))
    }
}

/// Light checkered pattern that stands in for a transparent canvas
/// behind the ticket preview when the user has turned off the export
/// background.
struct CheckeredBackgroundView: View {
    var body: some View {
        Canvas { ctx, size in
            let square: CGFloat = 12
            let light = Color.white
            let dark  = Color(hex: "E5E5E5")
            let cols = Int(ceil(size.width / square))
            let rows = Int(ceil(size.height / square))
            for r in 0..<rows {
                for c in 0..<cols {
                    let color = (r + c) % 2 == 0 ? light : dark
                    let rect = CGRect(
                        x: CGFloat(c) * square,
                        y: CGFloat(r) * square,
                        width: square,
                        height: square
                    )
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
        }
    }
}

// MARK: - Background style tile

/// Small thumbnail used in the background-style selector row. Renders
/// a scaled-down version of each background so the user can see what
/// they're picking.
private struct BackgroundStyleTile: View {
    let style: ExportBackgroundStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ExportBackgroundView(style: style)
                    .frame(height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.Text.primary : Color.Border.hairline,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                Text(style.displayName)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.Text.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

private struct ExportSheetPreviewHost: View {
    @State private var showSheet = true
    let ticket: Ticket

    var body: some View {
        Color.Background.default
            .ignoresSafeArea()
            .sheet(isPresented: $showSheet) {
                ExportSheet(ticket: ticket)
            }
    }
}

#Preview("Export sheet — horizontal ticket") {
    let ticket = TicketsStore.sampleTickets.first { $0.orientation == .horizontal }
        ?? TicketsStore.sampleTickets[0]
    return ExportSheetPreviewHost(ticket: ticket)
}

#Preview("Export sheet — vertical ticket") {
    let ticket = TicketsStore.sampleTickets.first { $0.orientation == .vertical }
        ?? TicketsStore.sampleTickets[0]
    return ExportSheetPreviewHost(ticket: ticket)
}
