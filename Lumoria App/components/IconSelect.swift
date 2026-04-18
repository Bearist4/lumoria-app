//
//  IconSelect.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=973-25020
//

import SwiftUI

/// A model describing one selectable app icon.
struct AppIconOption: Identifiable, Hashable {
    /// The alternate icon set name declared in Assets.xcassets. Pass `nil`
    /// for the primary (default) app icon.
    let alternateIconName: String?
    /// Display label.
    let name: String
    /// Preview asset used inside the tile. This is a separate image asset
    /// (PNG) drawn in-app — alternate app-icon sets cannot be rendered with
    /// `Image(iconName)` directly.
    let previewAsset: String

    var id: String { alternateIconName ?? "__default__" }
}

struct IconSelect: View {

    let option: AppIconOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(option.previewAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 14.144, style: .continuous))

                Text(option.name)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(1)
            }
            .padding(.vertical, 12)
            .frame(width: 121, height: 161)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? Color.Background.subtle : Color.Background.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.Border.strong : .clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Icon tiles") {
    HStack(spacing: 8) {
        IconSelect(
            option: AppIconOption(
                alternateIconName: nil,
                name: "Default",
                previewAsset: "logomark"
            ),
            isSelected: true
        ) {}

        IconSelect(
            option: AppIconOption(
                alternateIconName: "Noir",
                name: "Noir",
                previewAsset: "logomark"
            ),
            isSelected: false
        ) {}
    }
    .padding(24)
    .background(Color.Background.default)
}
