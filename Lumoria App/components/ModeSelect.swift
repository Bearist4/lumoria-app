//
//  ModeSelect.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=973-24488
//

import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light  = "Light"
    case dark   = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

struct ModeSelect: View {

    let mode: AppearanceMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                preview
                    .frame(width: 97, height: 107)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(mode.rawValue)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(Color.Text.primary)
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

    // MARK: - Mini preview

    /// Image-asset name per mode. Assets live under
    /// `Assets.xcassets/appearance/` — add a {mode}.imageset with the
    /// stylized Memories-screen thumbnail. Asset should be a single
    /// rendered image (for .system, bake the diagonal split into the
    /// asset itself).
    private var previewAssetName: String {
        switch mode {
        case .system: return "appearance/system"
        case .light:  return "appearance/light"
        case .dark:   return "appearance/dark"
        }
    }

    private var preview: some View {
        Image(previewAssetName)
            .resizable()
            .scaledToFill()
    }
}

// MARK: - Preview

#Preview("Mode tiles") {
    HStack(spacing: 8) {
        ModeSelect(mode: .system, isSelected: true)  {}
        ModeSelect(mode: .light,  isSelected: false) {}
        ModeSelect(mode: .dark,   isSelected: false) {}
    }
    .padding(24)
    .background(Color.Background.default)
}
