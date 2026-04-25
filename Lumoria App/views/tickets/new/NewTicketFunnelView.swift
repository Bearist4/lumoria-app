//
//  NewTicketFunnelView.swift
//  Lumoria App
//
//  Container for the 6-step new-ticket flow. Owns shared chrome: the
//  "New ticket" header, the current step body, and the bottom "Back / Next"
//  bar. Steps themselves live in dedicated `*Step.swift` files.
//

import Combine
import SwiftUI

struct NewTicketFunnelView: View {

    /// When provided, the funnel opens in edit mode: fields prefilled
    /// from this ticket, starting on the form step. The host view owns
    /// the actual save via `pendingEdit`.
    var initialTicket: Ticket? = nil

    /// Edit flow only — the Done button writes the fully-built edited
    /// ticket here just before dismissing, so the presenter (usually
    /// `TicketDetailView`) can run `store.update` + show the loader
    /// without racing the view lifecycle.
    var pendingEdit: Binding<Ticket?>? = nil

    /// Set when the funnel is launched from an import entry point
    /// (contextual menu on the `+` button). Primes `funnel.importSource`
    /// so the orientation step flows into `.import` instead of `.form`.
    var initialImportSource: ImportSource? = nil

    /// Raw `.pkpass` bytes handed in by the app-root `onOpenURL` handler
    /// when the user shared a pass into Lumoria. The import step uses
    /// this to skip the file picker and parse immediately.
    var initialPassData: Data? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @StateObject private var funnel = NewTicketFunnel()

    @State private var showAbandonAlert = false
    /// Combine subscription that mirrors funnel state to disk while
    /// onboarding is active. Held in @State so it lives for the
    /// duration of the funnel view.
    @State private var draftSaveCancellable: AnyCancellable? = nil
    /// Gates the `.allDone` cutout so it doesn't flash up the moment
    /// the success step appears (the print-reveal animation runs
    /// ~3.5s end-to-end). Flips true 4.5s after the funnel lands on
    /// `.success`. Resets when the user leaves the success step.
    @State private var allDoneOverlayReady: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header

            if funnel.step != .success {
                stepHeading
            }

            if funnel.step.prefersFullHeight {
                stepContent
                    .padding(.horizontal, 16)
                    .padding(.top, funnel.step == .success ? 0 : 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    stepContent
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(Color.Background.default)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .onboardingOverlay(
            step: .pickCategory,
            coordinator: onboardingCoordinator,
            anchorID: "funnel.categories",
            tip: OnboardingTipCopy(
                title: "Pick a category",
                body: "Tickets are separated into categories. Pick a category to continue."
            )
        )
        .onboardingOverlay(
            step: .pickTemplate,
            coordinator: onboardingCoordinator,
            anchorID: "funnel.firstTemplate",
            tip: OnboardingTipCopy(
                title: "Pick a template",
                body: "Each category has different templates that match it. You can also check the content of each template by tapping the information button."
            )
        )
        .onboardingOverlay(
            step: .fillInfo,
            coordinator: onboardingCoordinator,
            anchorID: "funnel.firstFormField",
            tip: OnboardingTipCopy(
                title: "Fill the required information",
                body: "Every template have specific information attached to it. Fill all the required information to edit your ticket."
            ),
            // Cutout sits over the departure airport field. Auto-dismiss
            // once the user has picked an airport so the rest of the
            // form becomes scrollable / tappable without forcing them
            // to advance the onboarding step early.
            gatedBy: funnel.step == .form && funnel.form.originAirport == nil
        )
        .onboardingOverlay(
            step: .pickStyle,
            coordinator: onboardingCoordinator,
            anchorID: "funnel.styles",
            tip: OnboardingTipCopy(
                title: "Select a style",
                body: "Some templates have alternative styles. Scroll through the options and tap the one you like to change how your ticket looks."
            )
        )
        .onboardingOverlay(
            step: .allDone,
            coordinator: onboardingCoordinator,
            anchorID: "success.actions",
            tip: OnboardingTipCopy(
                title: "Ticket created!",
                body: "Your ticket has been created. You can find it in All Tickets. You can now add it to a Memory or Export your ticket to use it in another app."
            ),
            gatedBy: allDoneOverlayReady
        )
        .onChange(of: funnel.step) { oldStep, newStep in
            // Advance the onboarding coordinator when the user leaves the
            // form step (Next tap). The funnel's advance() logic handles
            // the fillInfo → pickStyle | allDone branching.
            if oldStep == .form
                && onboardingCoordinator.currentStep == .fillInfo {
                Task { await onboardingCoordinator.advance(from: .fillInfo) }
            }

            // Gate the .allDone overlay until the print-reveal animation
            // has settled (~3.5s) plus a 1s breather. Reset when leaving
            // success in case the user hits Back.
            if newStep == .success {
                allDoneOverlayReady = false
                Task {
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    if funnel.step == .success {
                        allDoneOverlayReady = true
                    }
                }
            } else if oldStep == .success {
                allDoneOverlayReady = false
            }

            // Auto-persist only for new-ticket creation — the success
            // step's reveal animation reads `funnel.createdTicket` and
            // wants the write to fire as soon as the user lands.
            //
            // Edit flow is explicit: the Done button on the success step
            // calls `funnel.persist(using:)` directly, so the network
            // call can't be cut short by the view dismissing.
            guard newStep == .success, !funnel.isEditing else { return }
            Task {
                await funnel.persist(using: ticketsStore)
            }
        }
        .onAppear {
            if let ticket = initialTicket, funnel.editingTicketId == nil {
                funnel.prefill(from: ticket)
            }
            if let source = initialImportSource, funnel.importSource == nil {
                funnel.importSource = source
            }
            if let data = initialPassData, funnel.pendingPassData == nil {
                funnel.pendingPassData = data
            }
            if !funnel.isEditing {
                Analytics.track(.newTicketStarted(entryPoint: .gallery))
            }
            installOnboardingDraftBridge()
            // Cold-resume case: if hydration dropped us straight onto
            // the success step, the funnel.step onChange won't fire —
            // run the 4.5s gate here so the .allDone overlay still
            // waits for the print animation to settle.
            if funnel.step == .success {
                allDoneOverlayReady = false
                Task {
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    if funnel.step == .success {
                        allDoneOverlayReady = true
                    }
                }
            }
        }
        .onDisappear {
            guard funnel.createdTicket == nil, !funnel.isEditing else { return }
            let ms = Int(Date().timeIntervalSince(funnel.startedAt) * 1000)
            Analytics.track(.ticketFunnelAbandoned(
                stepReached: funnel.step.analyticsProp,
                timeInFunnelMs: ms
            ))
        }
        .alert(
            "Discard ticket?",
            isPresented: $showAbandonAlert
        ) {
            Button("Keep crafting", role: .cancel) { }
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Leave now? Your ticket won't be saved.")
        }
    }

    // MARK: - Header
    //
    // Shared across every step — same vertical slot, same X position.
    // On the success step the "New ticket" title is hidden (opacity 0)
    // so the X lines up with the title's centerline on other steps,
    // keeping the layout grid consistent across the flow. Tapping X
    // discards in-progress steps via an abandon alert, but dismisses
    // immediately on success (the ticket is already saved).

    private var header: some View {
        HStack(alignment: .center) {
            Text("New ticket")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)
                .opacity(funnel.step == .success ? 0 : 1)

            Spacer()

            LumoriaIconButton(systemImage: "xmark") {
                if funnel.step == .success {
                    dismiss()
                } else {
                    showAbandonAlert = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var stepHeading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(funnel.step.title)
                .font(.title2.bold())
                .foregroundStyle(Color.Text.primary)

            if let subtitle = funnel.step.subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(Color.Text.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Step body

    @ViewBuilder
    private var stepContent: some View {
        switch funnel.step {
        case .category:    NewTicketCategoryStep(funnel: funnel)
        case .template:    NewTicketTemplateStep(funnel: funnel)
        case .orientation: NewTicketOrientationStep(funnel: funnel)
        case .import:      NewTicketImportStep(funnel: funnel)
        case .form:
            VStack(spacing: 12) {
                if funnel.importFailureBanner {
                    importFailureBanner
                }
                NewTicketFormStep(funnel: funnel)
            }
        case .style:       NewTicketStyleStep(funnel: funnel)
        case .success:
            NewTicketSuccessStep(funnel: funnel, pendingEdit: pendingEdit) {
                dismiss()
            }
        }
    }

    // MARK: - Onboarding draft bridge

    /// Wires funnel ↔ disk while the onboarding tutorial is active.
    /// Hydrates from any existing draft on first appear, then debounces
    /// every funnel mutation to a single JSON write so a cold launch
    /// can drop the user back at the exact step they left.
    private func installOnboardingDraftBridge() {
        guard onboardingCoordinator.showOnboarding,
              !funnel.isEditing,
              initialImportSource == nil,
              initialTicket == nil else { return }

        if let draft = OnboardingFunnelDraftStore.load() {
            funnel.hydrate(from: draft)
            if let id = draft.createdTicketId,
               let saved = ticketsStore.tickets.first(where: { $0.id == id }) {
                funnel.createdTicket = saved
                funnel.createdTickets = [saved]
            }
        }

        // Subscribe to every funnel mutation. Debounce keeps a busy
        // form-fill from thrashing UserDefaults — only the settled
        // state lands on disk.
        draftSaveCancellable = funnel.objectWillChange
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak funnel] _ in
                guard let funnel else { return }
                let id = funnel.createdTicket?.id
                    ?? funnel.createdTickets.first?.id
                let snapshot = funnel.snapshot(createdTicketId: id)
                OnboardingFunnelDraftStore.save(snapshot)
            }
    }

    /// One-shot notice shown on the form step when the import parser
    /// couldn't extract enough detail. Stays until the user taps the
    /// close button so they can keep it around while they fill fields.
    private var importFailureBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.Text.secondary)
            Text("We couldn’t detect every field. Fill in the rest below.")
                .font(.footnote)
                .foregroundStyle(Color.Text.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                funnel.importFailureBanner = false
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.Text.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.Background.subtle)
        )
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if funnel.step == .success {
            // Success step has no bottom bar — its own actions
            // (Export / Add to Memory) live inside the step content,
            // and the X in the header handles dismiss.
            EmptyView()
        } else {
            HStack(spacing: 16) {
                if funnel.step != .category {
                    Button("Back") { funnel.goBack() }
                        .lumoriaButtonStyle(.tertiary, size: .large)
                        .frame(width: 100)
                }

                Button {
                    funnel.advance()
                } label: {
                    Text("Next")
                }
                .lumoriaButtonStyle(.primary, size: .large)
                .disabled(!funnel.canAdvance)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.Background.default.ignoresSafeArea(edges: .bottom))
        }
    }
}

// MARK: - Preview

#Preview("Funnel") {
    NewTicketFunnelView()
        .environmentObject(TicketsStore())
}
