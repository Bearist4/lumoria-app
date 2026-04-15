//
//  NewTicketFunnelView.swift
//  Lumoria App
//
//  Container for the 6-step new-ticket flow. Owns shared chrome: the
//  "New ticket" header, the current step body, and the bottom "Back / Next"
//  bar. Steps themselves live in dedicated `*Step.swift` files.
//

import SwiftUI

struct NewTicketFunnelView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ticketsStore: TicketsStore
    @StateObject private var funnel = NewTicketFunnel()

    var body: some View {
        VStack(spacing: 0) {
            if funnel.step != .success {
                header
                stepHeading
            }

            if funnel.step.prefersFullHeight {
                stepContent
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    stepContent
                        .padding(.horizontal, 16)
                        .padding(.top, funnel.step == .success ? 0 : 16)
                        .padding(.bottom, 24)
                }
            }

            bottomBar
        }
        .background(Color.Background.default)
        .task(id: funnel.step) {
            // Persist the ticket as soon as we land on the success step.
            if funnel.step == .success {
                await funnel.persist(using: ticketsStore)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("New ticket")
                .font(.system(size: 34, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.Text.primary)

            Spacer()

            LumoriaIconButton(systemImage: "xmark") { dismiss() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var stepHeading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(funnel.step.title)
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.26)
                .foregroundStyle(Color.Text.primary)

            if let subtitle = funnel.step.subtitle {
                Text(subtitle)
                    .font(.system(size: 17, weight: .regular))
                    .tracking(-0.43)
                    .foregroundStyle(Color.Text.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Step body

    @ViewBuilder
    private var stepContent: some View {
        switch funnel.step {
        case .category:    NewTicketCategoryStep(funnel: funnel)
        case .template:    NewTicketTemplateStep(funnel: funnel)
        case .orientation: NewTicketOrientationStep(funnel: funnel)
        case .form:        NewTicketFormStep(funnel: funnel)
        case .style:       NewTicketStyleStep(funnel: funnel)
        case .success:     NewTicketSuccessStep(funnel: funnel) { dismiss() }
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if funnel.step == .success {
            Button {
                dismiss()
            } label: {
                Text("Back to Home")
            }
            .lumoriaButtonStyle(.primary, size: .large)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.Background.default.ignoresSafeArea(edges: .bottom))
        } else {
            HStack(spacing: 16) {
                if funnel.step != .category {
                    Button("Back") { funnel.goBack() }
                        .lumoriaButtonStyle(.tertiary, size: .large)
                        .frame(width: 100)
                }

                Button {
                    funnel.advance()
                } label: {
                    Text("Next")
                }
                .lumoriaButtonStyle(.primary, size: .large)
                .disabled(!funnel.canAdvance)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.Background.default.ignoresSafeArea(edges: .bottom))
        }
    }
}

// MARK: - Preview

#Preview("Funnel") {
    NewTicketFunnelView()
        .environmentObject(TicketsStore())
}
