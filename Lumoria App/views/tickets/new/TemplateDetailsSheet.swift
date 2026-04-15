//
//  TemplateDetailsSheet.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1029-35941
//
//  Bottom sheet launched from a `TemplateTile`'s info button. Shows a preview
//  of the template plus the list of data points the user will need to fill in.
//

import SwiftUI

struct TemplateDetailsSheet: View {

    let kind: TicketTemplateKind
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(minimum: 150), spacing: 12),
        GridItem(.flexible(minimum: 150), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            closeRow

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    previewCard
                        .padding(.top, 8)

                    Text("In this template")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.26)
                        .foregroundStyle(Color.Text.primary)
                        .padding(.top, 24)

                    Text("The following information is needed in order to generate the ticket.")
                        .font(.system(size: 17, weight: .regular))
                        .tracking(-0.43)
                        .foregroundStyle(Color.Text.secondary)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(kind.requirements) { item in
                            requirementPill(item)
                        }
                    }
                    .padding(.top, 4)

                    Text("These information does not need to be accurate as you are not creating a real, usable ticket. Only the airport codes need to be accurate to generate a path between them.")
                        .font(.system(size: 13, weight: .regular))
                        .tracking(-0.08)
                        .foregroundStyle(Color.Text.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color.Background.default)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Close row

    private var closeRow: some View {
        HStack {
            LumoriaIconButton(systemImage: "xmark") { dismiss() }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Preview

    private var previewCard: some View {
        let ticket = Ticket(
            orientation: .horizontal,
            payload: NewTicketFunnel.previewPayload(for: kind)
        )
        return TicketPreview(ticket: ticket)
            .padding(.horizontal, 43)
            .padding(.vertical, 48)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.Background.subtle)
            )
    }

    // MARK: - Requirement pill

    private func requirementPill(_ item: TemplateRequirement) -> some View {
        VStack(spacing: 4) {
            Image(systemName: item.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.Text.primary)
                .frame(width: 32, height: 32)

            Text(item.label)
                .font(.system(size: 15, weight: .regular))
                .tracking(-0.23)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Background.subtle)
        )
    }
}

// MARK: - Preview

#Preview("Studio") {
    Color.black.sheet(isPresented: .constant(true)) {
        TemplateDetailsSheet(kind: .studio)
    }
}
