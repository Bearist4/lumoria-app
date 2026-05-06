//
//  InviteLandingView.swift
//  Lumoria App
//
//  Invite-only "More from Lumoria" landing — figma 972:23490 (notSent
//  / sent), figma 972:23491 (redeemed). Replaces the StoreKit paywall
//  for `.memoryLimit` / `.ticketLimit` triggers while
//  EntitlementStore.kPaymentsEnabled is false.
//

import SwiftUI
import UIKit

struct InviteLandingView: View {

    let trigger: PaywallTrigger

    @Environment(\.dismiss) private var dismiss
    @Environment(\.brandSlug) private var brandSlug
    @StateObject private var store: InvitesStore

    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showExplanation = false
    @State private var error: String? = nil

    init(trigger: PaywallTrigger, store: InvitesStore = InvitesStore()) {
        self.trigger = trigger
        self._store = StateObject(wrappedValue: store)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.Background.default
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    pinkHeader
                    contentBlock
                }
            }
            .scrollIndicators(.hidden)

            // Toolbar overlays the pink wash so the X / ? buttons line
            // up exactly with the EarlyAdopterPromo / NoSlotsSheet
            // family. Sits above the scroll layer so taps register.
            toolbar
                .padding(.horizontal, 16)
                .padding(.top, 16)
        }
        .task {
            await store.load()
            // Materialise a shareable token up-front so the link field
            // can render its real URL on first paint instead of waiting
            // for the user to tap "Share my link". Idempotent against
            // existing rows (load() already pulled them).
            if case .notSent = store.state {
                _ = await store.sendInvite()
            }
            Analytics.track(.invitePageViewed(state: invitePageStateProp))
        }
        .sheet(isPresented: $showShareSheet) {
            if !shareItems.isEmpty {
                ShareSheet(items: shareItems)
            }
        }
        .sheet(isPresented: $showExplanation) {
            InviteExplanationView()
        }
    }

    // MARK: - Pink header (figma 2146:159625)

    /// 300pt blurred pink wash that anchors the "More from Lumoria"
    /// pitch — same shape as the purple seat-counter on the early-
    /// adopter promo and the yellow warning on NoSlotsSheet, just
    /// without a glyph (the Invite landing leans on the title block
    /// alone for hierarchy).
    private var pinkHeader: some View {
        // Temporarily Colors/Blue/50 to make the cover area visible
        // during layout review — swap back to Colors/pink/50 to match
        // the Figma when the placement is approved.
        Color("Colors/Blue/50")
            .blur(radius: 50)
            .frame(height: 300)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleBlock
            bodyBlock
            // Link field always renders for non-redeemed states. While
            // the invite is being created (the auto-send on appear),
            // we paint a redacted placeholder so the row doesn't pop
            // in once the network call resolves.
            if !isRedeemed {
                if let invite = currentInvite {
                    linkField(invite.shareURL)
                } else {
                    linkPlaceholder
                }
            }
            primaryCTA
            footnote
            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Color.Feedback.Danger.text)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }

    private var linkPlaceholder: some View {
        HStack {
            Text("getlumoria.app/loading")
                .font(.body)
                .foregroundStyle(Color.Text.tertiary)
                .redacted(reason: .placeholder)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.InputField.Background.default)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.InputField.Border.default, lineWidth: 1)
                )
        )
    }

    private var isRedeemed: Bool {
        if case .redeemed = store.state { return true }
        return false
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            LumoriaIconButton(
                systemImage: "xmark",
                position: .onBackground
            ) {
                dismiss()
            }
            Spacer()
            LumoriaIconButton(
                systemImage: "questionmark",
                position: .onBackground
            ) {
                showExplanation = true
            }
        }
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("More from Lumoria")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)
            Text("by inviting a friend")
                .font(.title2.bold())
                .foregroundStyle(Color.Text.secondary)
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var bodyBlock: some View {
        switch store.state {
        case .redeemed:
            Text("You've used your invite. Delete a memory or a ticket to make room for a new one.")
                .font(.body)
                .foregroundStyle(Color.Text.primary)
                .fixedSize(horizontal: false, vertical: true)
        default:
            VStack(alignment: .leading, spacing: 12) {
                Text("Thank you for using Lumoria to craft beautiful tickets!")
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)

                (Text("You are running out of Memories or Ticket slots.")
                    .font(.body.bold())
                    .foregroundStyle(Color.Text.primary)
                 + Text(" ")
                 + Text("Invite a friend to gain 1 more Memory slot or 2 more ticket slots.")
                    .font(.body)
                    .foregroundStyle(Color.Text.primary))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Your friend will also get to choose between one or the other option for their account.")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Link field

    private func linkField(_ url: URL) -> some View {
        HStack(spacing: 8) {
            Text(url.absoluteString)
                .font(.body)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.InputField.Background.default)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.InputField.Border.default, lineWidth: 1)
                )
        )
    }

    // MARK: - Primary CTA

    @ViewBuilder
    private var primaryCTA: some View {
        switch store.state {
        case .redeemed:
            EmptyView()
        case .loading:
            shareButton(label: "Share my link", disabled: true)
                .redacted(reason: .placeholder)
        case .notSent:
            shareButton(label: "Share my link", disabled: false) {
                Task {
                    if let invite = await store.sendInvite() {
                        presentShare(for: invite)
                    } else if let message = store.errorMessage {
                        error = message
                    }
                }
            }
        case .sent(let invite):
            shareButton(label: "Share my link", disabled: false) {
                presentShare(for: invite)
            }
        }
    }

    /// Builds the rich share payload — pitch text + a
    /// `InviteShareItem` carrying the URL plus `LPLinkMetadata` so the
    /// share sheet renders the Lumoria icon + "Join Lumoria" preview
    /// row instead of a bare URL chip.
    private func presentShare(for invite: Invite) {
        let icon = UIImage(named: "brand/\(brandSlug)/logomark")
        let item = InviteShareItem(
            url: invite.shareURL,
            title: String(localized: "Join Lumoria"),
            icon: icon
        )
        let pitch = String(
            localized: "I've been making beautiful ticket stubs with Lumoria. Join me:"
        )
        shareItems = [pitch, item]
        showShareSheet = true
        Analytics.track(.inviteShared(
            channel: .system_share,
            inviteTokenHash: AnalyticsIdentity.hashString(invite.token)
        ))
    }

    private func shareButton(
        label: LocalizedStringKey,
        disabled: Bool,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black)
                )
        }
        .disabled(disabled)
    }

    // MARK: - Footnote

    private var footnote: some View {
        Text("This offer is valid once per account (referring or referee).\nNo credit card required.")
            .font(.caption2)
            .foregroundStyle(Color.Text.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var currentInvite: Invite? {
        switch store.state {
        case .sent(let invite):     return invite
        case .redeemed(let invite): return invite
        default:                    return nil
        }
    }

    private var invitePageStateProp: InvitePageStateProp {
        switch store.state {
        case .loading, .notSent: return .not_sent
        case .sent:              return .sent
        case .redeemed:          return .redeemed
        }
    }
}

#if DEBUG
private func previewStore(_ state: InvitesStore.ViewState) -> InvitesStore {
    let store = InvitesStore()
    store.setStateForPreview(state)
    return store
}

private var previewInvite: Invite {
    Invite(
        id: UUID(),
        inviterId: UUID(),
        token: "ABCDE23456",
        createdAt: Date(),
        revokedAt: nil,
        claimedBy: nil,
        claimedAt: nil,
        redeemedAt: nil
    )
}

private var previewRedeemedInvite: Invite {
    Invite(
        id: UUID(),
        inviterId: UUID(),
        token: "ABCDE23456",
        createdAt: Date().addingTimeInterval(-7 * 24 * 3600),
        revokedAt: nil,
        claimedBy: UUID(),
        claimedAt: Date().addingTimeInterval(-1 * 24 * 3600),
        redeemedAt: Date().addingTimeInterval(-1 * 24 * 3600)
    )
}

#Preview("Not sent") {
    InviteLandingView(trigger: .memoryLimit, store: previewStore(.notSent))
}

#Preview("Sent") {
    InviteLandingView(trigger: .memoryLimit, store: previewStore(.sent(previewInvite)))
}

#Preview("Redeemed") {
    InviteLandingView(trigger: .memoryLimit, store: previewStore(.redeemed(previewRedeemedInvite)))
}
#endif
