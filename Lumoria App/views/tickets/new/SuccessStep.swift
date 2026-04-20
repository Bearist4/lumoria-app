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
    /// Edit flow only — the Done button writes the edited ticket here
    /// before dismissing so the presenter runs the save + loader.
    var pendingEdit: Binding<Ticket?>? = nil
    /// Dismisses the whole funnel. Supplied by the container.
    var onBackHome: () -> Void

    @EnvironmentObject private var ticketsStore: TicketsStore

    @State private var showAddToMemory: Bool = false
    @State private var showExport: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            heroText

            previewCard
                .frame(maxHeight: .infinity)

            if let error = funnel.errorMessage {
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

            let source: TicketSourceProp = {
                switch funnel.importSource {
                case .wallet: return .wallet
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
            Text("All done!")
                .font(.largeTitle.bold())
                .foregroundStyle(heroGradient)
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
    }

    @ViewBuilder
    private var createPreviewCard: some View {
        if let saved = funnel.createdTicket {
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

    // MARK: - Actions

    @ViewBuilder
    private var actionsGrid: some View {
        if funnel.isEditing {
            // Edit flow — Done hands the prepared ticket to the
            // presenter (via `pendingEdit`) and dismisses immediately.
            // The presenter runs the save + loader so the user only
            // sees one loading state, outside the funnel.
            Button("Done") {
                pendingEdit?.wrappedValue = funnel.buildUpdatedTicket()
                onBackHome()
            }
            .lumoriaButtonStyle(.primary, size: .large)
        } else {
            VStack(spacing: 12) {
                Button("Export Ticket") {
                    showExport = true
                }
                .lumoriaButtonStyle(.secondary, size: .large)
                .disabled(funnel.createdTicket == nil)

                Button("Add to Memory") {
                    showAddToMemory = true
                }
                .lumoriaButtonStyle(.primary, size: .large)
                .disabled(funnel.createdTicket == nil)
            }
        }
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
