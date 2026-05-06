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
import VariableBlur

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

    /// Parsed share-extension payload handed in by the app-root drain
    /// handler. Populates the funnel before the import step runs and
    /// drives a category preset when the classifier returned one.
    var initialShareImport: ShareImportResult? = nil

    /// Optional category to lock the funnel onto when the share
    /// extension classified the payload (e.g. plane / concert).
    /// When nil the funnel opens at the category step.
    var initialCategory: TicketCategory? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @Environment(EntitlementStore.self) private var entitlement
    @Environment(Paywall.PresentationState.self) private var paywallState
    @StateObject private var funnel = NewTicketFunnel()

    @State private var showAbandonAlert = false
    /// Confirmation alert for the style-step reset affordance. The
    /// reset wipes the user's theme + per-element colour picks, so we
    /// gate it behind a destructive confirm.
    @State private var showStyleResetAlert: Bool = false
    /// Sheet bindings for success-step actions. Held at the funnel
    /// level so the actions can live in the shared bottom bar instead
    /// of inside the success step body.
    @State private var showAddToMemory: Bool = false
    @State private var showExport: Bool = false
    /// Combine subscription that mirrors funnel state to disk while
    /// onboarding is active. Held in @State so it lives for the
    /// duration of the funnel view.
    @State private var draftSaveCancellable: AnyCancellable? = nil
    /// Gates the `.allDone` cutout so it doesn't flash up the moment
    /// the success step appears (the print-reveal animation runs
    /// ~3.5s end-to-end). Flips true 4.5s after the funnel lands on
    /// `.success`. Resets when the user leaves the success step.
    @State private var allDoneOverlayReady: Bool = false
    /// Outstanding gate timer. Cancelled and restarted whenever the
    /// final ticket count changes (multi-leg journeys append to
    /// `createdTickets` one leg at a time, so a gate started at the
    /// initial count=1 reading would flip the overlay too early).
    @State private var allDoneGateTask: Task<Void, Never>? = nil
    /// Live keyboard height (0 when hidden). Drives the scroll layer's
    /// dynamic bottom safe-area inset so the focused TextField scrolls
    /// above the keyboard while the bar itself stays anchored to the
    /// physical screen bottom (root ignores `.keyboard` safe area).
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content layer — keyboard-aware. SwiftUI's default keyboard
            // avoidance shrinks this layer's frame when the keyboard
            // appears, which lets the ScrollView auto-scroll the focused
            // TextField above the keyboard.
            VStack(spacing: 0) {
                header

                if funnel.step != .success {
                    stepHeading
                }

                if funnel.step.prefersFullHeight {
                    stepContent
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, funnel.step == .success ? 0 : 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        // ScrollViewReader exposes a proxy that
                        // LumoriaDropdown reads from the environment to
                        // scroll itself into view on open, so the menu
                        // isn't clipped by the bottom bar when the
                        // field sits near the end of the form.
                        ScrollViewReader { proxy in
                            stepContent
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 24)
                                .environment(\.lumoriaScrollProxy, proxy)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .background(Color.Background.default)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Reserves bar height + live keyboard height inside the
                // scroll layer. ScrollView reads this inset and shrinks
                // its visible region accordingly, which is what triggers
                // the system's auto-scroll to keep the focused TextField
                // above the keyboard. The 96pt is the bar's intrinsic
                // height; `keyboardHeight` is published by the keyboard
                // observer below.
                Color.clear.frame(height: 96 + keyboardHeight)
            }

            // Bar layer — pinned flush with the physical bottom edge.
            // The outer ZStack ignores `.container` and `.keyboard` at
            // the bottom so this child's bottom alignment is the
            // physical screen edge regardless of keyboard state.
            bottomBar
        }
        .ignoresSafeArea(edges: .bottom)
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillShowNotification
            )
        ) { notification in
            guard
                let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            else { return }
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            withAnimation(.easeOut(duration: duration)) {
                keyboardHeight = frame.height
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillHideNotification
            )
        ) { notification in
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            withAnimation(.easeOut(duration: duration)) {
                keyboardHeight = 0
            }
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
            // has settled. Started on entry; restarted whenever the
            // ticket count changes (see the createdTickets onChange
            // below) so multi-leg journeys use the right duration.
            if newStep == .success {
                allDoneOverlayReady = false
                startAllDoneGate()
            } else if oldStep == .success {
                allDoneOverlayReady = false
                allDoneGateTask?.cancel()
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
        .onChange(of: funnel.createdTickets) { _, _ in
            // Multi-leg journeys append legs one at a time. Restart
            // the gate every time the count grows so the overlay
            // waits for ALL prints to finish, not just the first.
            guard funnel.step == .success else { return }
            startAllDoneGate()
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
            if let result = initialShareImport, funnel.pendingShareImport == nil {
                funnel.pendingShareImport = result
            }
            if let category = initialCategory, funnel.category == nil {
                funnel.category = category
                // Skip directly to the template picker when category
                // is preset — the share extension already classified.
                if funnel.step == .category {
                    funnel.step = .template
                }
            }
            if !funnel.isEditing {
                Analytics.track(.newTicketStarted(entryPoint: .gallery))
            }
            installOnboardingDraftBridge()
            // Cold-resume case: if hydration dropped us straight onto
            // the success step, the funnel.step onChange won't fire —
            // run the print-reveal gate here too.
            if funnel.step == .success {
                allDoneOverlayReady = false
                startAllDoneGate()
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
        .alert(
            "Reset style?",
            isPresented: $showStyleResetAlert
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                funnel.resetStyleToDefault()
            }
        } message: {
            Text("Your theme and colour picks will revert to the template's default.")
        }
        .sheet(isPresented: $showAddToMemory) {
            if !funnel.createdTickets.isEmpty {
                AddToMemorySheet(
                    tickets: funnel.createdTickets,
                    onCompleted: handleSuccessFinished
                )
            } else if let ticket = funnel.createdTicket {
                AddToMemorySheet(
                    ticket: ticket,
                    onCompleted: handleSuccessFinished
                )
            }
        }
        .sheet(isPresented: $showExport) {
            if let ticket = funnel.createdTicket {
                ExportSheet(ticket: ticket, onCompleted: handleSuccessFinished)
            }
        }
    }

    /// Called once the user has finished a success-screen action
    /// (export saved or ticket added to a memory). Advances the
    /// onboarding past `.exportOrAddMemory` so the end-cover sheet
    /// pops over the Memories tab, then dismisses the whole funnel so
    /// the user lands back on Memories instead of staring at the
    /// success screen.
    private func handleSuccessFinished() {
        if onboardingCoordinator.currentStep == .exportOrAddMemory {
            Task { await onboardingCoordinator.advance(from: .exportOrAddMemory) }
        }
        dismiss()
    }

    // MARK: - Header
    //
    // Shared across every step — same vertical slot, same X position.
    // Title swaps to "All done!" on the success step so it sits aligned
    // with the X icon button per the Figma success layout. Tapping X
    // discards in-progress steps via an abandon alert, but dismisses
    // immediately on success (the ticket is already saved).

    private var header: some View {
        HStack(alignment: .center) {
            Text(funnel.step == .success ? "All done!" : "New ticket")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)

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
            NewTicketSuccessStep(funnel: funnel)
        }
    }

    // MARK: - Onboarding draft bridge

    /// How long to wait before flipping `allDoneOverlayReady`. Tracks
    /// the print animation's actual duration: single ticket runs
    /// ~3.5 s end-to-end; multi-ticket sequences each print at ~2.0 s
    /// apiece (see TicketStackCarousel.perTicketDuration).
    private func printRevealGateNanoseconds() -> UInt64 {
        let count = max(funnel.createdTickets.count, 1)
        let seconds: TimeInterval = count > 1
            ? Double(count) * 2.0 + 0.5
            : 3.5
        return UInt64(seconds * 1_000_000_000)
    }

    /// (Re)starts the gate timer with the current ticket count.
    /// Cancelling any prior task so a stale timer (started when only
    /// the first leg had been persisted) doesn't trip the overlay
    /// before the rest of the legs finish printing.
    private func startAllDoneGate() {
        allDoneGateTask?.cancel()
        let ns = printRevealGateNanoseconds()
        allDoneGateTask = Task {
            try? await Task.sleep(nanoseconds: ns)
            if !Task.isCancelled, funnel.step == .success {
                allDoneOverlayReady = true
            }
        }
    }

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

    // MARK: - Advance gating

    /// Wraps `funnel.advance()` so the final hop into the success step
    /// can't blow the free-tier ticket cap. Multi-leg public-transport
    /// trips persist N rows in one go — without this gate a free user
    /// at 8 tickets could pick a 4-leg journey and silently land at 12.
    /// Edit flow + premium / grandfathered users skip the check; if it
    /// fires, the paywall router presents (InviteLanding or NoSlotsSheet).
    private func advanceOrPaywall() {
        guard !funnel.isEditing,
              advancingLandsOnSuccess,
              !ticketsStore.canCreate(
                  entitlement: entitlement,
                  adding: funnel.pendingTicketCount
              )
        else {
            funnel.advance()
            return
        }
        Paywall.present(
            for: .ticketLimit,
            entitlement: entitlement,
            state: paywallState
        )
    }

    /// True when the *next* `advance()` would land the funnel on
    /// `.success` — i.e. style step always, or form step when the
    /// chosen template skips the style step.
    private var advancingLandsOnSuccess: Bool {
        switch funnel.step {
        case .style: return true
        case .form:  return !funnel.hasStylesStep
        default:     return false
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        bottomBarButtons
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
            .background {
                // Progressive blur 0→100 top→bottom, with a 65% white
                // (light) / black (dark) tint on top so the buttons stay
                // legible. Clipped to the bar's rounded bottom corners so
                // both layers share the same silhouette.
                ZStack {
                    VariableBlurView(
                        maxBlurRadius: 20,
                        direction: .blurredBottomClearTop
                    )
                    Color("Colors/Opacity/White/inverse/65")
                }
                .clipShape(UnevenRoundedRectangle(
                    cornerRadii: .init(bottomLeading: 56, bottomTrailing: 56),
                    style: .continuous
                ))
            }
            // Bar reaches the physical bottom of the screen, passing
            // through the home-indicator safe area. The 32pt bottom
            // padding keeps the buttons inside that safe zone.
            .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var bottomBarButtons: some View {
        if funnel.step == .success {
            successBarButtons
        } else {
            HStack(spacing: 24) {
                if funnel.step != .category {
                    LumoriaIconButton(systemImage: "chevron.left") {
                        funnel.goBack()
                    }
                }

                Button {
                    advanceOrPaywall()
                } label: {
                    Text("Next")
                }
                .lumoriaButtonStyle(.primary, size: .medium)
                .disabled(!funnel.canAdvance)

                // Style step only — reset to the template's default
                // appears once the user has touched a theme or any
                // per-element colour. Confirms via destructive alert
                // because the wipe can't be undone in-funnel.
                if funnel.step == .style, funnel.isStyleModifiedFromDefault {
                    LumoriaIconButton(
                        systemImage: "arrow.counterclockwise",
                        position: .danger
                    ) {
                        showStyleResetAlert = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var successBarButtons: some View {
        if funnel.isEditing {
            // Edit flow — Done hands the prepared ticket back to the
            // presenter (via `pendingEdit`) and dismisses immediately.
            // The presenter runs the save + loader so the user only
            // sees one loading state, outside the funnel.
            Button("Done") {
                pendingEdit?.wrappedValue = funnel.buildUpdatedTicket()
                dismiss()
            }
            .lumoriaButtonStyle(.primary, size: .medium)
        } else {
            HStack(spacing: 24) {
                Button("Add to memory") {
                    showAddToMemory = true
                    if onboardingCoordinator.currentStep == .allDone {
                        Task { await onboardingCoordinator.chose(.addToMemory) }
                    }
                }
                .lumoriaButtonStyle(.secondary, size: .medium)
                .disabled(funnel.createdTicket == nil)

                Button("Export") {
                    showExport = true
                    if onboardingCoordinator.currentStep == .allDone {
                        Task { await onboardingCoordinator.chose(.export) }
                    }
                }
                .lumoriaButtonStyle(.primary, size: .medium)
                .disabled(funnel.createdTicket == nil)
            }
            .onboardingAnchor("success.actions")
        }
    }
}

// MARK: - Preview

#Preview("Funnel") {
    NewTicketFunnelView()
        .environmentObject(TicketsStore())
}
