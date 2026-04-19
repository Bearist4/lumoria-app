//
//  SuccessStep.swift
//  Lumoria App
//
//  Step 6 — the ticket has been created and saved. The user sees a hero
//  congratulation, a preview of the final ticket, and 4 action tiles.
//

import SwiftUI

struct NewTicketSuccessStep: View {

    @ObservedObject var funnel: NewTicketFunnel
    /// Dismisses the whole funnel. Supplied by the container.
    var onBackHome: () -> Void

    @EnvironmentObject private var ticketsStore: TicketsStore

    @State private var showAddToMemory: Bool = false
    @State private var showExport: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            heroText

            previewCard

            if funnel.isSaving {
                savingBanner
            } else if let error = funnel.errorMessage {
                errorBanner(error)
            }

            actionsGrid
        }
        .sheet(isPresented: $showAddToMemory) {
            if let ticket = funnel.createdTicket {
                AddToMemorySheet(ticket: ticket)
            }
        }
        .sheet(isPresented: $showExport) {
            if let ticket = funnel.createdTicket {
                ExportSheet(ticket: ticket)
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
                case .express, .orient, .night:
                    let t = funnel.trainForm
                    return (0, t.originStationLocation != nil, t.destinationStationLocation != nil)
                default:
                    let f = funnel.form
                    return (0, f.originAirport != nil, f.destinationAirport != nil)
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
                ticketsLifetime: lifetime
            ))

            Analytics.updateUserProperties([
                "tickets_created_lifetime": lifetime,
                "last_ticket_category": category.rawValue,
            ])

            if lifetime == 1 {
                Analytics.track(.firstTicketCreated(category: category, template: templateProp))
                Analytics.updateUserProperties(["has_created_first_ticket": true])
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

    // MARK: - Hero

    /// `linear-gradient(270deg, pink → yellow → orange → blue)` — applied to
    /// the first line only. 270deg in CSS = right→left, so the 0% stop sits
    /// at the trailing edge and the 100% stop at the leading edge.
    private var heroGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "FF9CCC"), location: 0.0),      // pink/300
                .init(color: Color(hex: "FDDC51"), location: 0.34135),  // yellow/300
                .init(color: Color(hex: "FFA96C"), location: 0.66827),  // orange/300
                .init(color: Color(hex: "57B7F5"), location: 1.0),      // blue/300
            ],
            startPoint: .trailing,
            endPoint: .leading
        )
    }

    private var heroText: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your ticket is ready.")
                .font(.largeTitle.bold())
                .foregroundStyle(heroGradient)

            Text("Give it a home.")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.Text.primary)
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewCard: some View {
        if let saved = funnel.createdTicket {
            TicketSaveRevealView(orientation: saved.orientation) {
                TicketPreview(ticket: saved, isCentered: true)
            }
            .id(saved.id)
            .padding(saved.orientation == .horizontal ? 16 : 64)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.Background.elevated)
            )
        } else if let preview = livePreviewTicket {
            TicketPreview(ticket: preview, isCentered: true)
                .padding(preview.orientation == .horizontal ? 16 : 64)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.Background.elevated)
                )
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

    // MARK: - Actions grid

    private var actionsGrid: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                actionTile(
                    title: "Add to memory",
                    systemImage: "folder.fill.badge.plus",
                    background: Color(hex: "EBF7FF"),
                    height: 167,
                    action: { showAddToMemory = true }
                )
                actionTile(
                    title: "Export",
                    systemImage: "square.and.arrow.up",
                    background: Color(hex: "FFEEE4"),
                    height: 167,
                    action: { showExport = true }
                )
            }
            actionTile(
                title: "Invite a friend",
                systemImage: "person.fill.badge.plus",
                background: Color(hex: "E3F6DE"),
                height: 120,
                action: { /* TODO: invite flow */ }
            )
        }
    }

    private func actionTile(
        title: String,
        systemImage: String,
        background: Color,
        height: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title)
                    .foregroundStyle(Color.Text.primary)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.Text.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(background)
            )
        }
        .buttonStyle(.plain)
        .disabled(funnel.createdTicket == nil)
        .opacity(funnel.createdTicket == nil ? 0.5 : 1)
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
