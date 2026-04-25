//
//  MemoryWidgetBackground.swift
//  Lumoria (widget)
//
//  Widget canvas drawn in SwiftUI. Small = single ticket card. Medium =
//  two ticket cards with perforated facing edges, matching the Figma
//  composition. Container lives on top of the transparent widget
//  containerBackground so anything outside these shapes shows through.
//

import SwiftUI

struct MemoryWidgetBackground: View {
    enum Variant { case small, medium }

    let memory: WidgetMemorySnapshot
    let variant: Variant

    var body: some View {
        switch variant {
        case .small:
            TicketCardShape(cornerRadius: 24)
                .fill(Color.white)

        case .medium:
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color(.systemGray6))
                    .frame(width: 108)
            }
        }
    }
}
