//
//  MemoryWidgetSmallView.swift
//  Lumoria (widget)
//
//  164 × 164 variant — memory name, ticket count, and a wrapped grid of
//  the categories present in that memory. Background is the user's
//  ticket-shaped art drawn by `MemoryWidgetEntryView`.
//

import SwiftUI
import WidgetKit

struct MemoryWidgetSmallView: View {
    let memory: WidgetMemorySnapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            WidgetFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(memory.categoryStyleRawValues, id: \.self) { rawValue in
                    Image(systemName: WidgetCategoryIcon.systemImage(for: rawValue))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity, alignment: .bottom)

            MemoryWidgetHeader(memory: memory)
                .padding(.top, 16)
                .padding(.leading, 16)
                .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
