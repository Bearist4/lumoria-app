//
//  EarlyAdopterPromoSheet.swift
//  Lumoria App
//
//  Modal pitch for the self-service early-adopter seat. Shows the
//  live remaining-seat count up top in a blurred purple wash, lays out
//  the deal + research expectations, and routes the CTA through a
//  destructive-style confirm alert before calling the claim RPC. On
//  success the badge flips and the Research row appears in Settings.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1983-129010
//

import SwiftUI

extension Notification.Name {
    /// Posted when something outside the SwiftUI tree wants to
    /// surface the early-adopter promo — e.g. a widget tap routed
    /// through `lumoria://promo/early-adopter`. ContentView listens
    /// and flips `showEarlyAdopterPromoChained` so the sheet pops
    /// over whatever tab is active.
    static let lumoriaShowEarlyAdopterPromo = Notification.Name("lumoria.promo.early-adopter")
}

struct EarlyAdopterPromoSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(EntitlementStore.self) private var entitlement

    @State private var showConfirmAlert: Bool = false
    @State private var isClaiming: Bool = false
    @State private var errorMessage: String? = nil

    private static let researchPolicyURL = URL(string: "https://getlumoria.app/research")!
    /// How often to repoll the seat count while the sheet is visible.
    /// The RPC is a single COUNT(*) so this stays cheap. The loop is
    /// cancelled automatically when the view goes away.
    private static let seatRefreshInterval: Duration = .seconds(10)

    var body: some View {
        ZStack(alignment: .top) {
            Color.Background.default
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    seatHeader
                    body(width: .infinity)
                }
            }
            .scrollIndicators(.hidden)

            // Close button overlay — sits over the purple wash so the
            // visual mirrors the Figma layout.
            HStack {
                LumoriaIconButton(systemImage: "xmark", size: .medium) {
                    dismiss()
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .task {
            while !Task.isCancelled {
                await entitlement.loadEarlyAdopterSeats()
                try? await Task.sleep(for: Self.seatRefreshInterval)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Background polls are suspended by iOS — refetch on
            // resume so the count is current before the next tick.
            if phase == .active {
                Task { await entitlement.loadEarlyAdopterSeats() }
            }
        }
        .alert(
            "Become an early adopter?",
            isPresented: $showConfirmAlert
        ) {
            Button("Not yet", role: .cancel) { }
            Button("Confirm") { Task { await claim() } }
        } message: {
            Text("This stamps your account as an early adopter and opts you in for occasional research surveys. You can revoke any time from Settings.")
        }
        .alert(
            "Couldn't claim a seat",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Seat header

    /// Big translucent seat counter. Mirrors the Figma's blurred
    /// `Purple/50` wash with a `Purple/500` numeral. Falls back to "—"
    /// while the count is loading so the header doesn't pop in.
    private var seatHeader: some View {
        ZStack {
            Color("Colors/Purple/50")
                .blur(radius: 50)

            Text(seatLabel)
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(Color("Colors/Purple/500"))
                .accessibilityLabel(seatAccessibilityLabel)
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
    }

    private var seatLabel: String {
        guard let remaining = entitlement.earlyAdopterSeatsRemaining else {
            return "—"
        }
        return "\(remaining)"
    }

    private var seatAccessibilityLabel: Text {
        guard let remaining = entitlement.earlyAdopterSeatsRemaining else {
            return Text("Loading remaining seats")
        }
        return Text("\(remaining) early-adopter seats remaining")
    }

    // MARK: - Body

    @ViewBuilder
    private func body(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Build a better Lumoria")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Lumoria is currently being built and tested in public. Eventually, Lumoria will become a paid service... except for \(EntitlementStore.earlyAdopterSeatCap) early adopters.")
                .font(.body)
                .foregroundStyle(Color.Text.primary)

            Text("What is expected from early adopters?")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.Text.primary)

            Text("Early adopters can use all the features available in Lumoria. You will be automatically opted in for feedback on the product as it is being built (surveys, rare interview requests).")
                .font(.body)
                .foregroundStyle(Color.Text.primary)

            Text("You always have a choice to opt out from research initiatives in the Research tab in your Settings.")
                .font(.footnote)
                .foregroundStyle(Color.Text.secondary)

            Spacer(minLength: 24)

            Button {
                if soldOut {
                    // No-op — button is disabled in this state, but
                    // belt + suspenders.
                    return
                }
                showConfirmAlert = true
            } label: {
                if isClaiming {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(soldOut ? "All seats taken" : "Become an early adopter")
                }
            }
            .lumoriaButtonStyle(.primary, size: .large)
            .disabled(isClaiming || soldOut)

            legalFootnote
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 64)
    }

    private var soldOut: Bool {
        entitlement.earlyAdopterSeatsRemaining == 0
    }

    /// Trailing legal blurb. Renders the email-usage disclosure plus
    /// an underlined "Read more here." that opens the research policy
    /// page in Safari.
    private var legalFootnote: some View {
        Text(legalAttributedString)
            .font(.footnote)
            .foregroundStyle(Color.Text.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .environment(\.openURL, OpenURLAction { url in
                openURL(url)
                return .handled
            })
    }

    private var legalAttributedString: AttributedString {
        var s = AttributedString(
            String(localized: "By becoming an early adopter, you accept that your email is going to be used to contact you directly about research topics on Lumoria. ")
        )
        var link = AttributedString(String(localized: "Read more here."))
        link.underlineStyle = .single
        link.link = Self.researchPolicyURL
        s.append(link)
        return s
    }

    // MARK: - Claim

    private func claim() async {
        guard !isClaiming else { return }
        isClaiming = true
        defer { isClaiming = false }
        do {
            try await entitlement.claimEarlyAdopterSeat()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch EntitlementStore.EarlyAdopterError.seatsExhausted {
            errorMessage = String(localized: "All 300 early-adopter seats are now taken. Try again later if any free up.")
        } catch {
            errorMessage = String(localized: "Something went wrong. Please try again.")
        }
    }
}

#if DEBUG
#Preview("Loading") {
    EarlyAdopterPromoSheet()
        .environment(EntitlementStore.previewInstance(
            tier: .free,
            monetisationEnabled: false
        ))
}
#endif
