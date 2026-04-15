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
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .tracking(-0.43)
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

    @ViewBuilder
    private var preview: some View {
        switch mode {
        case .system:
            // Split diagonal: light / dark
            ZStack {
                Color.white
                Color.black.mask(
                    GeometryReader { geo in
                        Path { p in
                            p.move(to: CGPoint(x: geo.size.width, y: 0))
                            p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                            p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                            p.closeSubpath()
                        }
                    }
                )
                previewContent(onDark: true, split: true)
            }
        case .light:
            ZStack {
                Color.white
                previewContent(onDark: false, split: false)
            }
        case .dark:
            ZStack {
                Color.black
                previewContent(onDark: true, split: false)
            }
        }
    }

    /// Stylized "app preview" content — status bar row, title block,
    /// two stacked content cards — tinted for light/dark surface.
    private func previewContent(onDark: Bool, split: Bool) -> some View {
        let tint: Color = onDark ? .white : .black
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Capsule().fill(tint.opacity(0.5)).frame(width: 14, height: 3)
                Spacer()
                Capsule().fill(tint.opacity(0.5)).frame(width: 20, height: 3)
            }

            RoundedRectangle(cornerRadius: 2)
                .fill(tint.opacity(0.7))
                .frame(width: 40, height: 6)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(tint.opacity(split ? 0.0 : 0.18))
                RoundedRectangle(cornerRadius: 3)
                    .fill(tint.opacity(0.18))
            }
            .frame(height: 34)
        }
        .padding(8)
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
