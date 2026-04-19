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
    /// SF Symbol name (fallback when `image` isn't provided).
    var systemImage: String? = nil
    /// Named asset from the catalog (preferred over `systemImage`).
    var imageName: String? = nil
    var isSelected: Bool = false
    var isAvailable: Bool = true
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            SelectionTile(isSelected: isSelected) {
                VStack(spacing: 12) {
                    thumbnail
                        .frame(width: 96, height: 80)

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

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnail: some View {
        if let imageName {
            Image(imageName)
                .resizable()
                .scaledToFit()
        } else if let systemImage {
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.Text.primary)
        } else {
            Rectangle().fill(Color.clear)
        }
    }
}

// MARK: - Preview

#Preview("Category tiles") {
    HStack(spacing: 16) {
        CategoryTile(title: "Plane", systemImage: "airplane")
        CategoryTile(title: "Plane", systemImage: "airplane", isSelected: true)
        CategoryTile(title: "Train", systemImage: "tram.fill", isAvailable: false)
    }
    .padding(24)
    .background(Color.Background.default)
}
