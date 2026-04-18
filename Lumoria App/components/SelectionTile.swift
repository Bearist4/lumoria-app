//
//  SelectionTile.swift
//  Lumoria App
//
//  Shared chrome for the four "pick one" tiles used in the new-ticket funnel:
//  category, template, style, orientation. Each tile renders caller-supplied
//  content (thumbnail + label) inside a 24pt-radius rounded container whose
//  fill, border, and label weight switch based on `isSelected`.
//

import SwiftUI

struct SelectionTile<Content: View>: View {

    let isSelected: Bool
    /// Horizontal padding applied to the inner content.
    var horizontalPadding: CGFloat = 16
    /// Vertical padding applied to the inner content.
    var verticalPadding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? Color.Background.subtle : Color.Background.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        Color.Border.strong,
                        lineWidth: isSelected ? 3 : 0
                    )
            )
    }
}

// MARK: - Label helper (shared by all 4 tiles)

/// Standard tile label — 20pt, regular or semibold depending on selection.
struct SelectionTileLabel: View {
    let text: String
    let isSelected: Bool

    var body: some View {
        Text(text)
            .font(.title3.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(Color.Text.primary)
            .lineLimit(1)
    }
}
