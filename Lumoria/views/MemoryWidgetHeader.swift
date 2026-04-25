//
//  MemoryWidgetHeader.swift
//  Lumoria (widget)
//
//  Shared header block used by both widget variants — memory name
//  (truncated to 1 line) and the tinted ticket count.
//

import SwiftUI

struct MemoryWidgetHeader: View {
    let memory: WidgetMemorySnapshot

    private var tintColor: Color {
        WidgetPalette.color300(for: memory.colorFamily)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(memory.name)
                .font(.title2).bold()
                .foregroundStyle(.black)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(ticketCountLabel)
                .font(.title3).fontWeight(.semibold)
                .fontDesign( .rounded)
                .foregroundStyle(tintColor)
        }
    }

    private var ticketCountLabel: String {
        memory.ticketCount == 1
            ? String(localized: "1 ticket")
            : String(localized: "\(memory.ticketCount) tickets")
    }
}
