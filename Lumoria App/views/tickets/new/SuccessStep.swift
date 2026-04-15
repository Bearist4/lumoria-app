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

    @State private var showAddToCollection: Bool = false
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
        .sheet(isPresented: $showAddToCollection) {
            if let ticket = funnel.createdTicket {
                AddToCollectionSheet(ticket: ticket)
            }
        }
        .sheet(isPresented: $showExport) {
            if let ticket = funnel.createdTicket {
                ExportSheet(ticket: ticket)
            }
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
                .font(.system(size: 34, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(heroGradient)

            Text("Give it a home.")
                .font(.system(size: 34, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Color.Text.primary)
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewCard: some View {
        if let ticket = funnel.createdTicket ?? livePreviewTicket {
            TicketPreview(ticket: ticket)
                .padding(ticket.orientation == .horizontal ? 16 : 64)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.Background.elevated)
                )
        }
    }

    /// Fallback preview while the Supabase insert is in-flight.
    private var livePreviewTicket: Ticket? {
        guard let payload = funnel.buildPayload() else { return nil }
        return Ticket(orientation: funnel.orientation, payload: payload)
    }

    // MARK: - Actions grid

    private var actionsGrid: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                actionTile(
                    title: "Add to collection",
                    systemImage: "folder.fill.badge.plus",
                    background: Color(hex: "EBF7FF"),
                    height: 167,
                    action: { showAddToCollection = true }
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
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(Color.Text.primary)
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.43)
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
                .font(.system(size: 15, weight: .regular))
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
                .font(.system(size: 13))
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
