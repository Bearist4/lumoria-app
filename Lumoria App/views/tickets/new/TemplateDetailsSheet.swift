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
                        .font(.title2.bold())
                        .foregroundStyle(Color.Text.primary)
                        .padding(.top, 24)

                    Text("The following information is needed in order to generate the ticket.")
                        .font(.body)
                        .foregroundStyle(Color.Text.secondary)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(kind.requirements) { item in
                            requirementPill(item)
                        }
                    }
                    .padding(.top, 4)

                    Text("This info doesn't need to be accurate — you're not making a real ticket. Only airport codes must be real, to draw the path.")
                        .font(.footnote)
                        .foregroundStyle(Color.Text.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color.Background.default)
        .presentationDragIndicator(.visible)
        .onAppear {
            Analytics.track(.templateDetailsViewed(
                category: kind.analyticsCategory,
                template: kind.analyticsTemplate
            ))
        }
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
        return TicketPreview(ticket: ticket, isCentered: true)
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
                .font(.headline)
                .foregroundStyle(Color.Text.primary)
                .frame(width: 32, height: 32)

            Text(item.label)
                .font(.subheadline)
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
