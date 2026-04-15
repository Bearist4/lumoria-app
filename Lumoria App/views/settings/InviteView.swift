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
    @StateObject private var store = InvitesStore()

    @State private var showShareSheet = false
    @State private var shareInvite: Invite?
    @State private var showRevokeConfirm = false
    @State private var copyToast: String? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color.Background.default.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Invite")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(0.4)
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
        .task { await store.load() }
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
            Button("Keep it", role: .cancel) { }
        } message: {
            Text("You'll get a new invite to share. The current link will stop working.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let invite = shareInvite {
                ShareSheet(items: [invite.shareURL])
            }
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
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.26)
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
                .font(.system(size: 13, weight: .regular))
                .tracking(-0.08)
                .foregroundStyle(Color(hex: "D94544"))
        }
    }

    // MARK: - Not sent

    @ViewBuilder
    private var notSentContent: some View {
        IllustrationCard {
            NotSentIllustration()
        }

        TitleBlock(
            title: "You have one invite.",
            description: "Give it to someone who'll love it. When they join, you both get a new collection."
        )
        .padding(.top, 8)

        LumoriaCallout(
            title: "How invites work",
            description: "You have one invite to give. When your friend joins and creates their first ticket, a new collection unlocks for you both. Once your invite is redeemed, it's gone. Make it count.",
            type: .information
        )
        .padding(.top, 8)

        Button {
            Task {
                if let invite = await store.sendInvite() {
                    shareInvite = invite
                    UIPasteboard.general.string = invite.shareURL.absoluteString
                    showShareSheet = true
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
        IllustrationCard {
            SentIllustration(sentDate: invite.createdAt)
        }

        TitleBlock(
            title: "Your invite is out there.",
            description: "Waiting for them to join. When they do, a new collection is yours."
        )
        .padding(.top, 8)

        Spacer(minLength: 40)

        VStack(spacing: 8) {
            Button {
                UIPasteboard.general.string = invite.shareURL.absoluteString
                copyToast = "Link copied"
                shareInvite = invite
                showShareSheet = true
            } label: {
                Text("Copy link again")
            }
            .lumoriaButtonStyle(.secondary)

            Button(role: .destructive) {
                showRevokeConfirm = true
            } label: {
                Text("Revoke invite")
            }
            .lumoriaButtonStyle(.danger)
        }
        .padding(.top, 24)
    }

    // MARK: - Redeemed

    @ViewBuilder
    private func redeemedContent(_ invite: Invite) -> some View {
        IllustrationCard {
            Color.clear
        }

        TitleBlock(
            title: "It worked.",
            description: "You unlocked a new collection slot."
        )
        .padding(.top, 8)

        Spacer(minLength: 80)

        Button {
            dismiss()
        } label: {
            Text("Create a collection")
        }
        .lumoriaButtonStyle(.primary)
        .padding(.top, 24)
    }
}

// MARK: - Illustration card (shared shell)

private struct IllustrationCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.Background.elevated)

            // Aurora glow — soft green radial at the bottom center.
            RadialGradient(
                colors: [
                    Color(red: 0.78, green: 1.0, blue: 0.78).opacity(0.85),
                    Color(red: 0.78, green: 1.0, blue: 0.78).opacity(0.0)
                ],
                center: UnitPoint(x: 0.5, y: 1.05),
                startRadius: 10,
                endRadius: 220
            )
            .allowsHitTesting(false)

            content()
        }
        .frame(height: 258)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Title block

private struct TitleBlock: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.26)
                .foregroundStyle(Color.Text.primary)

            Text(description)
                .font(.system(size: 17, weight: .regular))
                .tracking(-0.43)
                .foregroundStyle(Color.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Illustrations

/// Mini "preview" card sitting over the aurora glow — evokes the invite
/// the recipient will see.
private struct NotSentIllustration: View {
    var body: some View {
        ZStack {
            // Envelope silhouette behind the card.
            Image(systemName: "envelope.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 170)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                .offset(y: 24)

            // Preview card.
            VStack(spacing: 6) {
                Image("brand/default/logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 14)

                Text("You're invited.")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(-0.12)
                    .foregroundStyle(Color(red: 1.0, green: 0.48, blue: 0.42))

                Text("Someone thinks you'd love\ncollecting your travels here.")
                    .font(.system(size: 8, weight: .regular))
                    .tracking(0.06)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black)
            }
            .padding(12)
            .frame(width: 151, height: 171)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            .offset(y: -8)
        }
    }
}

/// Closed envelope with "Sent {date}" pill overlay.
private struct SentIllustration: View {
    let sentDate: Date

    var body: some View {
        ZStack {
            Image(systemName: "envelope.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 170)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

            LumoriaPill(label: "Sent \(formatted(sentDate))")
                .offset(y: 28)
        }
    }

    private func formatted(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMMM d, yyyy"
        return df.string(from: date)
    }
}

// MARK: - Share sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("Not sent") {
    NavigationStack { InviteView() }
}
