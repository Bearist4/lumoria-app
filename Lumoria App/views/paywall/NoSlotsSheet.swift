//
//  NoSlotsSheet.swift
//  Lumoria App
//
//  Modal shown when a former early adopter (or any free-tier user
//  who has already redeemed their invite) tries to create a new
//  memory or ticket while at the cap. Re-pitches the early-adopter
//  seat as the way out, since invite-based bonus slots are no longer
//  available.
//
//  Distinct from `InviteLandingView` — that one is shown when the
//  user CAN still earn a +1 / +2 bonus by inviting a friend.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2155-176421
//

import SwiftUI

struct NoSlotsSheet: View {

    /// Which resource the user just hit the cap on. Drives the count
    /// + copy: "X tickets" vs "X memories".
    let trigger: PaywallTrigger
    /// Number of items the user currently has. Rendered into the body
    /// copy: "You have currently 12 tickets…". Caller passes the live
    /// count from the relevant store.
    let currentCount: Int
    /// Tapped when the user picks the early-adopter CTA. The host
    /// dismisses this sheet and presents `EarlyAdopterPromoSheet`
    /// after a beat so SwiftUI doesn't drop the second sheet.
    let onBecomeEarlyAdopter: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.Background.default
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    warningHeader
                    body(width: .infinity)
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
    }

    // MARK: - Header

    /// Yellow-50 wash with a blurred warning glyph centered. Mirrors
    /// the EarlyAdopterPromoSheet's purple seat-counter header so the
    /// two cap-related modals feel like a family.
    private var warningHeader: some View {
        ZStack {
            Color("Colors/Yellow/50")
                .blur(radius: 50)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(Color.Feedback.Warning.icon)
                .accessibilityLabel(Text("No slots available"))
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Body

    @ViewBuilder
    private func body(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("No slot available")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(headlineCopy)
                .font(.body)
                .foregroundStyle(Color.Text.primary)

            Text("Become an early adopter to get unlimited \(resourceWord) or delete older \(resourceWord) before creating new ones.")
                .font(.body)
                .foregroundStyle(Color.Text.primary)

            Text("Your \(resourceWord) are counted from the oldest to the newest.")
                .font(.footnote)
                .foregroundStyle(Color.Text.secondary)

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
                onBecomeEarlyAdopter()
            } label: {
                Text("Become an early adopter")
            }
            .lumoriaButtonStyle(.primary, size: .large)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 64)
    }

    // MARK: - Copy helpers

    private var resourceWord: String {
        switch trigger.limitedResource {
        case .memories: return String(localized: "memories")
        case .tickets:  return String(localized: "tickets")
        case .none:     return String(localized: "items")
        }
    }

    private var headlineCopy: String {
        String(
            localized:
                "You have currently \(currentCount) \(resourceWord). You reached the maximum limit of \(resourceWord) you can have on a regular account."
        )
    }
}

#if DEBUG
#Preview("Tickets") {
    NoSlotsSheet(
        trigger: .ticketLimit,
        currentCount: 12,
        onBecomeEarlyAdopter: {}
    )
}

#Preview("Memories") {
    NoSlotsSheet(
        trigger: .memoryLimit,
        currentCount: 4,
        onBecomeEarlyAdopter: {}
    )
}
#endif
