//
//  PaywallView.swift
//  Lumoria App
//
//  Sheet-style paywall matching the Figma design.
//
//  The file is split into:
//    - `PaywallContent`: a pure SwiftUI view driven entirely by inputs.
//      No environment, no services, no async work in init. Used by
//      Xcode #Preview blocks so the canvas doesn't need to launch the
//      full app process.
//    - `PaywallView`: the live, app-wired entry point. Reads
//      EntitlementStore from environment, owns a PurchaseService, and
//      forwards the resolved props to PaywallContent.
//
//  Default (969:20169) — title "Lumoria Premium", single "Upgrade now"
//    CTA, used by every non-limit trigger.
//  Limit reached (969:20173 / 969:20171) — title
//    "Out of {memories|tickets}" with the resource word coloured
//    orange, two-CTA row: primary purchase button + secondary
//    "Invite a friend".
//

import SwiftUI

// MARK: - Wired entry point

struct PaywallView: View {
    let trigger: PaywallTrigger
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementStore.self) private var entitlement
    @State private var purchase: PurchaseService
    @State private var selected: PaywallPlan = .monthly
    @State private var showInvite: Bool = false
    @State private var error: String? = nil

    init(trigger: PaywallTrigger, entitlement: EntitlementStore) {
        self.trigger = trigger
        self._purchase = State(initialValue: PurchaseService(entitlement: entitlement))
    }

    var body: some View {
        PaywallContent(
            trigger: trigger,
            selected: $selected,
            prices: storeKitPrices,
            trialAvailable: entitlement.trialAvailable,
            monthlyPriceLabel: purchase.displayPrice(for: .monthly) ?? "$3.99",
            isPurchasing: purchase.isPurchasing,
            errorMessage: error,
            onClose: { dismiss() },
            onPurchase: handlePurchase,
            onInvite: { showInvite = true }
        )
        .task {
            await purchase.loadProducts()
        }
        .sheet(isPresented: $showInvite) {
            InviteView()
        }
    }

    private func handlePurchase() {
        Task {
            if await purchase.purchase(selected) {
                dismiss()
            } else if let f = purchase.lastError {
                error = description(of: f)
            }
        }
    }

    private var storeKitPrices: [PaywallPlan: String] {
        var map: [PaywallPlan: String] = [:]
        for plan in PaywallPlan.allCases {
            if let p = purchase.displayPrice(for: plan) {
                map[plan] = p
            }
        }
        return map
    }

    private func description(of failure: PurchaseService.Failure) -> String {
        switch failure {
        case .notSignedIn:          return "You need to be signed in."
        case .verificationFailed:   return "Couldn't verify the purchase. Try again."
        case .rpcFailed(let m):     return "Server didn't accept the purchase. (\(m))"
        case .storeKitError(let m): return m
        }
    }
}

// MARK: - Pure layout (preview-friendly)

struct PaywallContent: View {

    let trigger: PaywallTrigger
    @Binding var selected: PaywallPlan
    let prices: [PaywallPlan: String]
    let trialAvailable: Bool
    let monthlyPriceLabel: String
    let isPurchasing: Bool
    let errorMessage: String?
    let onClose: () -> Void
    let onPurchase: () -> Void
    let onInvite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            LumoriaIconButton(
                systemImage: "xmark",
                size: .large,
                position: .onBackground,
                action: onClose
            )
            .padding(.horizontal, 24)
            .padding(.top, 16)

            titleBlock
                .padding(.horizontal, 24)
                .padding(.top, 24)

            featureList
                .padding(.horizontal, 24)
                .padding(.top, 32)

            Spacer(minLength: 24)

            PlanCard(selected: $selected, prices: prices)
                .padding(.horizontal, 24)

            footer
                .padding(.horizontal, 24)
                .padding(.top, 16)

            if let errorMessage { errorBanner(errorMessage) }
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.Background.default)
    }

    // MARK: - Title + subtitle

    @ViewBuilder
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            title
                .font(.largeTitle.bold())
                .foregroundStyle(.black)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(Color.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var title: some View {
        if let resource = trigger.limitedResource {
            (Text("Out of ")
                .foregroundStyle(.black)
             + Text(resource.rawValue)
                .foregroundStyle(Color(red: 1.0, green: 0.616, blue: 0.298))
            )
        } else {
            Text("Lumoria Premium")
        }
    }

    private var subtitle: String {
        if let resource = trigger.limitedResource {
            return "You've reached the limit for free \(resource.rawValue). Upgrade today or invite a friend to Lumoria to create a new one."
        }
        return "Upgrade today to Lumoria Premium and enjoy creating tickets to the fullest."
    }

    // MARK: - Feature bullets

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 8) {
            featureRow(symbol: "star",                  text: "All templates across all categories")
            featureRow(symbol: "checkmark.seal",        text: "Clean exports, no Lumoria mark")
            featureRow(symbol: "list.bullet.clipboard", text: "Import tickets from Wallet")
            featureRow(symbol: "map",                   text: "Map, Timeline, Widgets…")
            featureRow(symbol: "printer",               text: "Print-ready quality")
        }
    }

    private func featureRow(symbol: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(.black)
                .frame(width: 32, height: 32)
            Text(text)
                .font(.headline)
                .foregroundStyle(.black)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            if trialAvailable && selected == .monthly {
                trustLine
            }
            ctaRow
        }
    }

    private var trustLine: some View {
        Text("14-day free trial, then \(monthlyPriceLabel)/month")
            .font(.footnote)
            .foregroundStyle(Color.Text.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var ctaRow: some View {
        if trigger.isLimitReached {
            HStack(spacing: 12) {
                purchaseButton
                inviteButton
            }
        } else {
            purchaseButton
        }
    }

    private var purchaseButton: some View {
        Button {
            onPurchase()
        } label: {
            Text(purchaseButtonLabel)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(isPurchasing)
    }

    private var purchaseButtonLabel: String {
        if selected == .monthly && trialAvailable {
            return "Try for 14 days"
        }
        return "Upgrade now"
    }

    private var inviteButton: some View {
        Button {
            onInvite()
        } label: {
            Text("Invite a friend")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color(red: 0.929, green: 0.929, blue: 0.929),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func errorBanner(_ msg: String) -> some View {
        Text(msg)
            .font(.footnote)
            .foregroundStyle(Color.Feedback.Danger.icon)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 8)
    }
}

// MARK: - Previews (lightweight — render PaywallContent directly)

#if DEBUG

private struct PaywallPreview: View {
    let trigger: PaywallTrigger
    let trialAvailable: Bool
    @State private var selected: PaywallPlan = .monthly

    var body: some View {
        PaywallContent(
            trigger: trigger,
            selected: $selected,
            prices: [
                .monthly:  "$3.99",
                .annual:   "$24.99",
                .lifetime: "$59.99",
            ],
            trialAvailable: trialAvailable,
            monthlyPriceLabel: "$3.99",
            isPurchasing: false,
            errorMessage: nil,
            onClose:    { },
            onPurchase: { },
            onInvite:   { }
        )
    }
}

#Preview("Default — Lumoria Premium") {
    PaywallPreview(trigger: .upgradeFromSettings, trialAvailable: false)
}

#Preview("Out of memories · trial available") {
    PaywallPreview(trigger: .memoryLimit, trialAvailable: true)
}

#Preview("Out of memories · trial used") {
    PaywallPreview(trigger: .memoryLimit, trialAvailable: false)
}

#Preview("Out of tickets · trial available") {
    PaywallPreview(trigger: .ticketLimit, trialAvailable: true)
}

#endif
