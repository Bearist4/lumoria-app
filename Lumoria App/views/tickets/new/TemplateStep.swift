//
//  TemplateStep.swift
//  Lumoria App
//
//  Step 2 — pick one template inside the chosen category. Each row is a
//  TemplateTile showing a stock horizontal preview.
//

import SwiftUI

struct NewTicketTemplateStep: View {

    @ObservedObject var funnel: NewTicketFunnel
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @Environment(EntitlementStore.self) private var entitlement
    @State private var detailsFor: TicketTemplateKind?
    /// Drives the early-adopter promo when a free user taps a gated
    /// template (plane: prism / heritage / terminal). Tap is captured
    /// before `funnel.template` is set so the picker doesn't latch
    /// onto a template the user can't actually use.
    @State private var showEarlyAdopterPromo: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(availableTemplates.enumerated()), id: \.element) { idx, kind in
                TemplateTile(
                    title: kind.displayName,
                    previewPayload: NewTicketFunnel.previewPayload(for: kind),
                    isSelected: funnel.template == kind,
                    showsPremiumBadge: kind.isEarlyAdopterOnly,
                    onTap: { handleTap(kind) },
                    onInfoTap: { detailsFor = kind }
                )
                .onboardingAnchor(
                    idx == 0 ? "funnel.firstTemplate" : "unused.tpl.\(kind.rawValue)"
                )
            }
        }
        .sheet(item: $detailsFor) { kind in
            TemplateDetailsSheet(kind: kind)
        }
        .sheet(isPresented: $showEarlyAdopterPromo) {
            EarlyAdopterPromoSheet()
                .environment(entitlement)
        }
        .onChange(of: funnel.template) { _, newValue in
            guard let newValue else { return }
            Analytics.track(.ticketTemplateSelected(
                category: newValue.analyticsCategory,
                template: newValue.analyticsTemplate
            ))
            if onboardingCoordinator.currentStep == .pickTemplate {
                onboardingCoordinator.pendingStyleStep = funnel.hasStylesStep
                Task { await onboardingCoordinator.advance(from: .pickTemplate) }
            }
        }
    }

    private var availableTemplates: [TicketTemplateKind] {
        funnel.category?.templates ?? []
    }

    /// Selection gate. Early-adopter templates fire the promo for
    /// non-adopters; everything else flows straight through to
    /// `funnel.template = kind` exactly like before.
    private func handleTap(_ kind: TicketTemplateKind) {
        if kind.isEarlyAdopterOnly, !entitlement.isEarlyAdopter {
            showEarlyAdopterPromo = true
            return
        }
        funnel.template = kind
    }
}
