//
//  PaywallView.swift
//  Lumoria App
//
//  Sheet-style paywall matching the Figma design.
//
//  Default (969:20169) — title "Lumoria Premium", single "Upgrade now"
//    CTA, used by every non-limit trigger.
//  Limit reached (969:20173 trial / 969:20171 trial used) — title
//    "Out of {memories|tickets}" with the resource word coloured
//    orange, two-CTA row: primary purchase button + secondary
//    "Invite a friend".
//
//  Layout (top to bottom): close button (top-leading) → title +
//  subtitle → 5-bullet feature list → 3 plan tiles → trial trust
//  copy (only when trial-available) → CTA row.
//

import SwiftUI

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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            closeButton
                .padding(.horizontal, 24)
                .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    titleBlock
                    featureList
                    PlanCard(selected: $selected, prices: storeKitPrices)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }

            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .padding(.top, 8)

            if let error { errorBanner(error) }
        }
        .background(Color.Background.default)
        .task {
            await purchase.loadProducts()
        }
        .sheet(isPresented: $showInvite) {
            InviteView()
        }
    }

    // MARK: - Close button (top-leading)

    private var closeButton: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.05), in: Circle())
            }
            .accessibilityLabel("Close")
            Spacer()
        }
    }

    // MARK: - Title + subtitle

    @ViewBuilder
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            title
                .font(.system(size: 34, weight: .bold))
                .kerning(0.4)
                .foregroundStyle(.black)
                .lineSpacing(0)

            Text(subtitle)
                .font(.system(size: 17))
                .kerning(-0.43)
                .foregroundStyle(Color.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var title: some View {
        if let resource = trigger.limitedResource {
            // "Out of {resource}" with the resource word coloured orange.
            (Text("Out of ")
                .foregroundStyle(.black)
             + Text(resource.rawValue)
                .foregroundStyle(Color(red: 1.0, green: 0.616, blue: 0.298)) // warm orange
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
            featureRow(symbol: "star",                    text: "All templates across all categories")
            featureRow(symbol: "checkmark.seal",          text: "Clean exports, no Lumoria mark")
            featureRow(symbol: "list.bullet.clipboard",   text: "Import tickets from Wallet")
            featureRow(symbol: "map",                     text: "Map, Timeline, Widgets…")
            featureRow(symbol: "printer",                 text: "Print-ready quality")
        }
    }

    private func featureRow(symbol: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            // 32×32 icon slot to match Figma spec.
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 32, height: 32)
            Text(text)
                .font(.system(size: 17, weight: .semibold))
                .kerning(-0.43)
                .foregroundStyle(.black)
        }
    }

    // MARK: - Footer (trust copy + CTA row)

    private var footer: some View {
        VStack(spacing: 12) {
            if entitlement.trialAvailable && selected == .monthly {
                trustLine
            }
            ctaRow
        }
    }

    private var trustLine: some View {
        Text("14-day free trial, then \(monthlyPriceLabel)/month")
            .font(.system(size: 13))
            .foregroundStyle(Color.Text.secondary)
            .multilineTextAlignment(.center)
    }

    private var monthlyPriceLabel: String {
        purchase.displayPrice(for: .monthly) ?? "$3.99"
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

    // Black filled button. Label flips to "Try for 14 days" only when
    // the user is monthly + trial-available.
    private var purchaseButton: some View {
        Button {
            Task {
                if await purchase.purchase(selected) {
                    dismiss()
                } else if let f = purchase.lastError {
                    error = description(of: f)
                }
            }
        } label: {
            Text(purchaseButtonLabel)
                .font(.system(size: 17, weight: .semibold))
                .kerning(-0.43)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(purchase.isPurchasing)
    }

    private var purchaseButtonLabel: String {
        if selected == .monthly && entitlement.trialAvailable {
            return "Try for 14 days"
        }
        return "Upgrade now"
    }

    // Gray secondary button — only shows on limit-reached variants.
    private var inviteButton: some View {
        Button {
            showInvite = true
        } label: {
            Text("Invite a friend")
                .font(.system(size: 17, weight: .semibold))
                .kerning(-0.43)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color(red: 0.929, green: 0.929, blue: 0.929),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Helpers

    private var storeKitPrices: [PaywallPlan: String] {
        var map: [PaywallPlan: String] = [:]
        for plan in PaywallPlan.allCases {
            if let p = purchase.displayPrice(for: plan) {
                map[plan] = p
            }
        }
        return map
    }

    private func errorBanner(_ msg: String) -> some View {
        Text(msg)
            .font(.footnote)
            .foregroundStyle(Color.Feedback.Danger.icon)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
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

// MARK: - Previews

#if DEBUG

private final class PreviewPaywallProfileService: ProfileServicing, @unchecked Sendable {
    func fetch() async throws -> Profile {
        Profile(
            userId: UUID(),
            showOnboarding: false,
            onboardingStep: .done
        )
    }
    func setStep(_ step: OnboardingStep) async throws {}
    func setShowOnboarding(_ value: Bool) async throws {}
    func replay() async throws {}
}

private final class PreviewPaywallAppSettingsService: AppSettingsServicing, @unchecked Sendable {
    let monetisationEnabled: Bool
    init(monetisationEnabled: Bool) {
        self.monetisationEnabled = monetisationEnabled
    }
    func fetch() async throws -> AppSettings {
        AppSettings(
            id: "singleton",
            monetisationEnabled: monetisationEnabled,
            updatedAt: nil
        )
    }
}

@MainActor
private func previewEntitlement() -> EntitlementStore {
    let store = EntitlementStore(
        profileService: PreviewPaywallProfileService(),
        appSettingsService: PreviewPaywallAppSettingsService(monetisationEnabled: true)
    )
    Task { await store.refresh() }
    return store
}

#Preview("Default — Lumoria Premium") {
    let entitlement = previewEntitlement()
    return PaywallView(trigger: .upgradeFromSettings, entitlement: entitlement)
        .environment(entitlement)
}

#Preview("Out of memories") {
    let entitlement = previewEntitlement()
    return PaywallView(trigger: .memoryLimit, entitlement: entitlement)
        .environment(entitlement)
}

#Preview("Out of tickets") {
    let entitlement = previewEntitlement()
    return PaywallView(trigger: .ticketLimit, entitlement: entitlement)
        .environment(entitlement)
}

#endif
