//
//  InviteRewardSheet.swift
//  Lumoria App
//
//  One sheet, two roles. Same shell (blue/50 cover, title block,
//  body copy, two `InviteChoiceCard`s, primary Confirm, footnote)
//  with copy that swaps based on whether the signed-in user is the
//  referrer (sent the invite) or the referree (used the invite).
//
//  Confirm calls `claim_invite_reward(p_kind:)` and then asks the
//  coordinator to consume — clears the pending state so the sheet
//  dismisses and the entitlement store picks up the +1 / +2 bonus
//  on the next refresh.
//
//  Designs:
//    - Referrer:  figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2146-160593
//    - Referree:  figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2147-161597
//

import SwiftUI

struct InviteRewardSheet: View {

    let role: InvitesStore.PendingReward
    let onClaimed: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementStore.self) private var entitlement

    @State private var selection: InviteRewardKind = .memory
    @State private var isClaiming: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color.Background.default
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    coverHeader
                    contentBlock
                }
            }
            .scrollIndicators(.hidden)

            HStack {
                LumoriaIconButton(systemImage: "xmark", size: .medium) {
                    dismiss()
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .alert(
            "Couldn't save your choice",
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

    // MARK: - Header

    private var coverHeader: some View {
        Color("Colors/Blue/50")
            
            .frame(height: 220)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Content

    private var contentBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleBlock
            Text(bodyCopy)
                .font(.body)
                .foregroundStyle(Color.Text.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                InviteChoiceCard(
                    label: "1 additional memory",
                    isSelected: selection == .memory,
                    action: { selection = .memory }
                ) { memoryIllustration }

                InviteChoiceCard(
                    label: "2 additional ticket slots",
                    isSelected: selection == .tickets,
                    action: { selection = .tickets }
                ) { ticketIllustration }
            }
            .padding(.vertical, 16)

            Button {
                Task { await confirm() }
            } label: {
                if isClaiming {
                    ProgressView().tint(.white)
                } else {
                    Text("Confirm")
                }
            }
            .lumoriaButtonStyle(.primary, size: .large)
            .disabled(isClaiming)

            Text("Once your benefit selected, you will not be able to modify it.")
                .font(.caption2)
                .foregroundStyle(Color.Text.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)
            Text(subtitle)
                .font(.title2.bold())
                .foregroundStyle(Color.Text.secondary)
        }
    }

    // MARK: - Illustrations

    private var memoryIllustration: some View {
        Image("reward/memory")
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 130)
    }

    private var ticketIllustration: some View {
        Image("reward/ticket")
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 130)
    }

    // MARK: - Copy

    private var title: LocalizedStringKey {
        switch role {
        case .referrer: return "Congratulations!"
        case .referree: return "More from Lumoria"
        }
    }

    private var subtitle: LocalizedStringKey {
        switch role {
        case .referrer: return "Your link has been redeemed."
        case .referree: return "Thanks to your friend."
        }
    }

    private var bodyCopy: LocalizedStringKey {
        switch role {
        case .referrer:
            return "You can now choose one of the benefits from inviting a user to Lumoria. They will remain forever linked to your account."
        case .referree:
            return "You joined Lumoria and created your first ticket with the invitation link from your friend. You can now unlock an additional benefit on Lumoria."
        }
    }

    // MARK: - Confirm

    private func confirm() async {
        guard !isClaiming else { return }
        isClaiming = true
        defer { isClaiming = false }
        let ok = await InvitesStore.claimReward(kind: selection)
        if ok {
            await entitlement.refresh()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onClaimed()
            dismiss()
        } else {
            errorMessage = String(localized: "Something went wrong. Please try again.")
        }
    }
}

#if DEBUG
#Preview("Referrer") {
    InviteRewardSheet(role: .referrer, onClaimed: {})
        .environment(EntitlementStore.previewInstance(
            tier: .free,
            monetisationEnabled: false
        ))
}

#Preview("Referree") {
    InviteRewardSheet(role: .referree, onClaimed: {})
        .environment(EntitlementStore.previewInstance(
            tier: .free,
            monetisationEnabled: false
        ))
}
#endif
