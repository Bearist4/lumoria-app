//
//  InviteView.swift
//  Lumoria App
//
//  Design:
//    Not sent: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=972-23490
//    Sent:     figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=970-22832
//    Redeemed: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=972-23491
//

import SwiftUI
import UIKit

struct InviteView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: InvitesStore

    @State private var showShareSheet = false
    @State private var shareInvite: Invite?
    @State private var showRevokeConfirm = false
    @State private var copyToast: String? = nil

    init(store: InvitesStore = InvitesStore()) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.Background.default.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Invite")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.Text.primary)
                        .padding(.top, 64)

                    stateContent
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }

            topBar
                .padding(.horizontal, 16)
                .padding(.top, 6)
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .task { await store.load() }
        .onAppear {
            let stateProp: InvitePageStateProp = {
                switch store.state {
                case .loading, .notSent: return .not_sent
                case .sent:              return .sent
                case .redeemed:          return .redeemed
                }
            }()
            Analytics.track(.invitePageViewed(state: stateProp))
        }
        .lumoriaToast($copyToast)
        .confirmationDialog(
            "Revoke invite?",
            isPresented: $showRevokeConfirm,
            titleVisibility: .visible
        ) {
            Button("Revoke invite", role: .destructive) {
                if case .sent(let invite) = store.state {
                    Task { await store.revoke(invite) }
                }
            }
            Button("Keep invite", role: .cancel) { }
        } message: {
            Text("You'll get a new invite to share. The current link will stop working.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let invite = shareInvite {
                ShareSheet(items: [invite.shareURL])
            }
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        switch store.state {
        case .sent(let invite):
            VStack(spacing: 8) {
                Button {
                    UIPasteboard.general.string = invite.shareURL.absoluteString
                    copyToast = String(localized: "Link copied")
                    shareInvite = invite
                    showShareSheet = true
                    Analytics.track(.inviteShared(
                        channel: .copy_link,
                        inviteTokenHash: AnalyticsIdentity.hashString(invite.token)
                    ))
                } label: {
                    Text("Copy new link")
                }
                .lumoriaButtonStyle(.secondary)

                Button(role: .destructive) {
                    showRevokeConfirm = true
                } label: {
                    Text("Revoke invite")
                }
                .lumoriaButtonStyle(.danger)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .background(Color.Background.default.ignoresSafeArea(edges: .bottom))

        case .redeemed:
            Button {
                // TODO: wire to the premium upgrade flow.
                dismiss()
            } label: {
                Text("Upgrade to Premium")
            }
            .lumoriaButtonStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .background(Color.Background.default.ignoresSafeArea(edges: .bottom))

        default:
            EmptyView()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            LumoriaIconButton(
                systemImage: "arrow.left",
                position: .onBackground
            ) {
                dismiss()
            }
            Spacer()
        }
    }

    // MARK: - State switch

    @ViewBuilder
    private var stateContent: some View {
        switch store.state {
        case .loading:
            IllustrationCard { Color.clear }
                .redacted(reason: .placeholder)

            VStack(alignment: .leading, spacing: 4) {
                Text("Loading")
                    .font(.title2.bold())
                    .redacted(reason: .placeholder)
            }
            .padding(.top, 8)

        case .notSent:
            notSentContent

        case .sent(let invite):
            sentContent(invite)

        case .redeemed(let invite):
            redeemedContent(invite)
        }

        if let message = store.errorMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.Feedback.Danger.text)
        }
    }

    // MARK: - Not sent

    @ViewBuilder
    private var notSentContent: some View {
        IllustrationCard {
            Image("invitation/available")
                .resizable()
                .scaledToFit()
                .padding(32)
        }

        TitleBlock(
            title: "You have one invite.",
            description: "Give it to someone who'll love it. When they join, you both get a new memory."
        )
        .padding(.top, 8)

        LumoriaCallout(
            title: "How invites work",
            description: "You have one invite to give. When your friend joins and creates their first ticket, a new memory unlocks for you both. Once your invite is redeemed, it's gone. Make it count.",
            type: .information
        )
        .padding(.top, 8)

        Button {
            Task {
                if let invite = await store.sendInvite() {
                    shareInvite = invite
                    UIPasteboard.general.string = invite.shareURL.absoluteString
                    showShareSheet = true
                    Analytics.track(.inviteShared(
                        channel: .system_share,
                        inviteTokenHash: AnalyticsIdentity.hashString(invite.token)
                    ))
                }
            }
        } label: {
            Text("Send your invite")
        }
        .lumoriaButtonStyle(.primary)
        .padding(.top, 24)
    }

    // MARK: - Sent

    @ViewBuilder
    private func sentContent(_ invite: Invite) -> some View {
        // Copy link + Revoke CTAs live in `.safeAreaInset(edge: .bottom)`
        // on `body` so they stay pinned to the device bottom.
        IllustrationCard {
            ZStack {
                Image("invitation/sent")
                    .resizable()
                    .scaledToFit()
                    .padding(64)

                LumoriaPill(label: "Sent \(formattedDate(invite.createdAt))")
                    .offset(y: 28)
            }
        }

        TitleBlock(
            title: "Your invite is out there.",
            description: "Waiting for them to join. When they do, a new memory is yours."
        )
        .padding(.top, 8)
    }

    // MARK: - Redeemed

    @ViewBuilder
    private func redeemedContent(_ invite: Invite) -> some View {
        // No illustration — centered tertiary-toned text block. The
        // "Upgrade to Premium" CTA lives in `.safeAreaInset(edge: .bottom)`
        // on `body` so it stays pinned to the device bottom.
        Spacer(minLength: 120)

        VStack(spacing: 8) {
            Text("Invitation accepted.")
                .font(.title2.bold())
                .foregroundStyle(Color.Text.tertiary)
                .multilineTextAlignment(.center)

            Text("You both benefit from an extra memory slot. Need more? Upgrade to Lumoria Premium and create unlimited memories.")
                .font(.body)
                .foregroundStyle(Color.Text.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)

        Spacer(minLength: 120)
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMMM d, yyyy"
        return df.string(from: date)
    }
}

// MARK: - Illustration card (shared shell)

private struct IllustrationCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.Background.elevated)

            content()
        }
        .frame(height: 258)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Title block

private struct TitleBlock: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(Color.Text.primary)

            Text(description)
                .font(.body)
                .foregroundStyle(Color.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#if DEBUG
private func previewStore(_ state: InvitesStore.ViewState) -> InvitesStore {
    let store = InvitesStore()
    store.setStateForPreview(state)
    return store
}

private var previewSampleInvite: Invite {
    Invite(
        id: UUID(),
        inviterId: UUID(),
        token: "ABCDE23456",
        createdAt: Date().addingTimeInterval(-3 * 24 * 3600),
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
    NavigationStack {
        InviteView(store: previewStore(.notSent))
    }
}

#Preview("Sent") {
    NavigationStack {
        InviteView(store: previewStore(.sent(previewSampleInvite)))
    }
}

#Preview("Redeemed") {
    NavigationStack {
        InviteView(store: previewStore(.redeemed(previewRedeemedInvite)))
    }
}
#endif
