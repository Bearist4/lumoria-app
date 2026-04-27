//
//  InviteExplanationView.swift
//  Lumoria App
//
//  Sheet shown when the user taps "Invite a friend" on the limit-hit
//  paywall. Explains the one-shot invite mechanic in 3 steps and
//  hands off to the system share sheet via "Share my invite link".
//
//  Owns its own InvitesStore — on appear it loads the existing invite
//  if one exists, otherwise creates a new one when the share button
//  is first tapped. That keeps the screen self-contained and means
//  the paywall doesn't have to pre-fetch the URL.
//
//  Figma: 969:20172
//

import SwiftUI

struct InviteExplanationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var invitesStore = InvitesStore()
    @State private var showShareSheet = false
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            LumoriaIconButton(
                systemImage: "xmark",
                size: .large,
                position: .onBackground,
                action: { dismiss() }
            )
            .padding(.horizontal, 24)
            .padding(.top, 16)

            titleBlock
                .padding(.horizontal, 24)
                .padding(.top, 24)

            timeline
                .padding(.horizontal, 24)
                .padding(.top, 32)

            Spacer(minLength: 24)

            footerCaption
                .padding(.horizontal, 24)

            shareButton
                .padding(.horizontal, 24)
                .padding(.top, 12)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.Feedback.Danger.icon)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.Background.default)
        .task {
            await invitesStore.load()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = inviteURL {
                ShareSheet(items: [
                    "I've been making beautiful ticket stubs with Lumoria. Join me in:",
                    url,
                ])
            }
        }
    }

    // MARK: - Title

    @ViewBuilder
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Bring a friend.")
                    .font(.largeTitle.bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.27, green: 0.51, blue: 0.96),
                                Color(red: 1.0,  green: 0.62, blue: 0.30),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Get one more trip.")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.black)
            }
            Text("Your invite is personal. One friend, one extra collection, yours to keep.")
                .font(.body)
                .foregroundStyle(Color.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepTimelineRow(
                heading: "Share your link",
                body: "You only get one, send it to someone who'll use it."
            ) {
                Image(systemName: "link")
            }
            StepTimelineRow(
                heading: "Your friend makes their first ticket",
                body: "They create one ticket, that's all it takes."
            ) {
                Image(systemName: "ticket.fill")
            }
            StepTimelineRow(
                heading: "You unlock a new collection",
                body: "Permanently yours. No expiry, no catch.",
                isLast: true
            ) {
                Image(systemName: "rectangle.stack.fill")
            }
        }
    }

    // MARK: - Footer

    private var footerCaption: some View {
        Text("You only get one invite, ever. Make it count.")
            .font(.footnote)
            .foregroundStyle(Color.Text.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var shareButton: some View {
        Button {
            Task { await prepareAndShare() }
        } label: {
            HStack(spacing: 8) {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                }
                Text("Share my invite link")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(isGenerating || invitesStore.state == .loading)
    }

    // MARK: - Share helpers

    private var inviteURL: URL? {
        switch invitesStore.state {
        case .sent(let invite), .redeemed(let invite):
            return invite.shareURL
        case .loading, .notSent:
            return nil
        }
    }

    private func prepareAndShare() async {
        // If we already have an invite, share immediately.
        if inviteURL != nil {
            showShareSheet = true
            return
        }

        // Otherwise create one, then share.
        isGenerating = true
        defer { isGenerating = false }

        guard await invitesStore.sendInvite() != nil else {
            errorMessage = invitesStore.errorMessage
            return
        }
        showShareSheet = true
    }
}

// MARK: - Previews

#if DEBUG

#Preview("Invite explanation") {
    InviteExplanationView()
}

#endif
