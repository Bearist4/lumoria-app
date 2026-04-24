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
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(ticketCountLabel)
                .font(.system(size: 17, design: .rounded).weight(.semibold))
                .foregroundStyle(tintColor)
        }
    }

    private var ticketCountLabel: String {
        memory.ticketCount == 1
            ? String(localized: "1 ticket")
            : String(localized: "\(memory.ticketCount) tickets")
    }
}
