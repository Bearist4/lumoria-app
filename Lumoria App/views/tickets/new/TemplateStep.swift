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
    @State private var detailsFor: TicketTemplateKind?

    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(availableTemplates.enumerated()), id: \.element) { idx, kind in
                TemplateTile(
                    title: kind.displayName,
                    previewPayload: NewTicketFunnel.previewPayload(for: kind),
                    isSelected: funnel.template == kind,
                    onTap: { funnel.template = kind },
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
        .onboardingOverlay(
            step: .pickTemplate,
            coordinator: onboardingCoordinator,
            anchorID: "funnel.firstTemplate",
            tip: OnboardingTipCopy(
                title: "Pick a template",
                body: "Each category has different templates that match it. You can also check the content of each template by tapping the information button."
            )
        )
    }

    private var availableTemplates: [TicketTemplateKind] {
        funnel.category?.templates ?? []
    }
}
