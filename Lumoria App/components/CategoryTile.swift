//
//  CategoryTile.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=369-3427
//
//  Pick-one tile used at the first step of the new-ticket funnel to choose a
//  ticket *category* (plane, train, concert, …). An icon sits above a 20pt
//  label; the whole tile toggles to a selected style on tap.
//

import SwiftUI

struct CategoryTile: View {

    let title: String
    /// Emoji glyph painted above the title. One per category.
    let emoji: String
    var isSelected: Bool = false
    var isAvailable: Bool = true
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            SelectionTile(isSelected: isSelected) {
                VStack(spacing: 12) {
                    Text(emoji)
                        .font(.system(size: 56))
                        .frame(width: 96, height: 80)
                        .accessibilityHidden(true)

                    SelectionTileLabel(text: title, isSelected: isSelected)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.5)
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(MotionTokens.impulse, value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Preview

#Preview("Category tiles") {
    HStack(spacing: 16) {
        CategoryTile(title: "Plane", emoji: "✈️")
        CategoryTile(title: "Plane", emoji: "✈️", isSelected: true)
        CategoryTile(title: "Train", emoji: "🚆", isAvailable: false)
    }
    .padding(24)
    .background(Color.Background.default)
}
