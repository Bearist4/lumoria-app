//
//  SuccessStep.swift
//  Lumoria App
//
//  Step 6 — the ticket has been created and saved. The body renders the
//  print-reveal preview card filling the area between the funnel header
//  and the bottom bar. Actions (Add to memory / Export, or Done in the
//  edit flow) live in the funnel's shared bottom bar.
//

import SwiftUI

struct NewTicketSuccessStep: View {

    @ObservedObject var funnel: NewTicketFunnel

    @EnvironmentObject private var ticketsStore: TicketsStore
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            previewCard
                .frame(maxHeight: .infinity)

            if !funnel.autoFilledFields.isEmpty {
                autoFilledNotice
            }

            if let error = funnel.errorMessage {
                errorBanner(error)
            }
        }
        .onChange(of: funnel.createdTicket) { _, created in
            guard let created,
                  let template = funnel.template else { return }

            let category = template.analyticsCategory
            let templateProp = template.analyticsTemplate
            let orientation = funnel.orientation.analyticsProp
            let styleId = funnel.selectedStyleId
            let lifetime = ticketsStore.tickets.count

            let (fieldCount, hasOrigin, hasDest): (Int, Bool, Bool) = {
                switch template {
                case .express, .orient, .night, .post, .glow:
                    let t = funnel.trainForm
                    return (0, t.originStationLocation != nil, t.destinationStationLocation != nil)
                case .concert:
                    let e = funnel.eventForm
                    return (0, e.venueLocation != nil, false)
                case .underground, .sign, .infoscreen, .grid:
                    let u = funnel.undergroundForm
                    return (0, u.originStation != nil, u.destinationStation != nil)
                default:
                    let f = funnel.form
                    return (0, f.originAirport != nil, f.destinationAirport != nil)
                }
            }()

            let source: TicketSourceProp = {
                switch funnel.importSource {
                case .wallet: return .wallet
                case .share:  return .share
                case .none:   return .gallery
                }
            }()

            Analytics.track(.ticketCreated(
                category: category,
                template: templateProp,
                orientation: orientation,
                styleId: styleId,
                fieldFillCount: fieldCount,
                hasOriginLocation: hasOrigin,
                hasDestinationLocation: hasDest,
                ticketsLifetime: lifetime,
                source: source
            ))

            Analytics.updateUserProperties([
                "tickets_created_lifetime": lifetime,
                "last_ticket_category": category.rawValue,
            ])

            if lifetime == 1 {
                Analytics.track(.firstTicketCreated(category: category, template: templateProp))
                Analytics.updateUserProperties(["has_created_first_ticket": true])
            }

            // Whichever step the user is currently on (fillInfo or
            // pickStyle), drive the coordinator forward so the allDone
            // overlay appears over the SuccessStep actions. Wait for
            // the TicketSaveRevealView print animation (~3.5s) before
            // surfacing the overlay.
            let current = onboardingCoordinator.currentStep
            if current == .pickStyle || current == .fillInfo {
                Task {
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    await onboardingCoordinator.advance(from: current)
                }
            }
        }
        .onChange(of: funnel.errorMessage) { _, err in
            guard let err else { return }
            Analytics.track(.ticketCreationFailed(
                stepReached: .success,
                errorType: err
            ))
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewCard: some View {
        Group {
            if funnel.isEditing {
                editPreviewCard
            } else {
                createPreviewCard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.Background.elevated)
        )
        // Clip at the card so the multi-ticket carousel's in-flight
        // ticket — which can briefly overflow the carousel area while
        // it's rotated 90° during print — is bounded by the rounded
        // card edge instead of being sliced mid-ticket by an inner
        // `.clipped()`.
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var createPreviewCard: some View {
        if funnel.createdTickets.count > 1 {
            // Multi-leg journey — print each ticket into a tilted
            // stack and let the rider swipe between them.
            TicketStackCarousel(tickets: funnel.createdTickets)
                .padding(.vertical, 16)
        } else if let saved = funnel.createdTicket {
            TicketSaveRevealView(orientation: saved.orientation) {
                TicketPreview(ticket: saved, isCentered: true)
            }
            .id(saved.id)
            .padding(saved.orientation == .horizontal ? 16 : 64)
        } else {
            TicketSaveSlotPlaceholder()
                .padding(16)
        }
    }

    /// Edit flow — no printer animation, just the current (in-progress)
    /// ticket rendered at hero size. Tapping Done hands the prepared
    /// ticket back to the presenter; the loader appears on the detail
    /// view, not here.
    @ViewBuilder
    private var editPreviewCard: some View {
        if let payload = funnel.buildPayload() {
            let preview = Ticket(
                orientation: funnel.orientation,
                payload: payload,
                styleId: funnel.selectedStyleId
            )
            TicketPreview(ticket: preview, isCentered: true)
                .padding(preview.orientation == .horizontal ? 16 : 64)
        }
    }

    /// Fallback preview while the Supabase insert is in-flight. Must
    /// carry the picked `styleId` so the preview matches the final
    /// saved ticket immediately — otherwise the default style renders
    /// first and flashes to the selected one when `createdTicket`
    /// arrives.
    private var livePreviewTicket: Ticket? {
        guard let payload = funnel.buildPayload() else { return nil }
        return Ticket(
            orientation: funnel.orientation,
            payload: payload,
            styleId: funnel.selectedStyleId
        )
    }

    // MARK: - Banners

    private var savingBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Saving your ticket…")
                .font(.subheadline)
                .foregroundStyle(Color.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.Background.subtle)
        )
    }

    /// Info banner listing the field labels that `NewTicketFunnel`
    /// filled with placeholder copy on advance, so the user knows what
    /// we touched and can edit the saved ticket later if they want to
    /// swap the copy.
    private var autoFilledNotice: some View {
        let fields = funnel.autoFilledFields
            .joined(separator: ", ")
        return HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.Text.secondary)
            Text("We filled in \(fields) for you. Edit the ticket later to swap the copy.")
                .font(.footnote)
                .foregroundStyle(Color.Text.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.Background.subtle)
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.Feedback.Danger.icon)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.Feedback.Danger.text)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.Feedback.Danger.subtle)
        )
    }
}
