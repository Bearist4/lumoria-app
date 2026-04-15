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
    @State private var detailsFor: TicketTemplateKind?

    var body: some View {
        VStack(spacing: 16) {
            ForEach(availableTemplates, id: \.self) { kind in
                TemplateTile(
                    title: kind.displayName,
                    previewPayload: NewTicketFunnel.previewPayload(for: kind),
                    isSelected: funnel.template == kind,
                    onTap: { funnel.template = kind },
                    onInfoTap: { detailsFor = kind }
                )
            }
        }
        .sheet(item: $detailsFor) { kind in
            TemplateDetailsSheet(kind: kind)
        }
    }

    private var availableTemplates: [TicketTemplateKind] {
        funnel.category?.templates ?? []
    }
}
