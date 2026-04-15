//
//  LumoriaButton.swift
//  Lumoria App
//
//  Implements the Lumoria button design system.
//  Hierarchy: Primary · Secondary · Tertiary · Danger
//  Size:      Large (60pt) · Medium (48pt) · Small (36pt)
//  States:    Default · Pressed · Inactive (disabled)
//

import SwiftUI

// MARK: - Types

enum LumoriaButtonHierarchy {
    case primary, secondary, tertiary, danger
}

enum LumoriaButtonSize {
    case large, medium, small

    var height: CGFloat {
        switch self {
        case .large:  60
        case .medium: 48
        case .small:  36
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .large, .medium: 24
        case .small:          16
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .large, .medium: 17
        case .small:          15
        }
    }
}

// MARK: - ButtonStyle

struct LumoriaButtonStyle: ButtonStyle {
    var hierarchy: LumoriaButtonHierarchy = .primary
    var size: LumoriaButtonSize = .large

    func makeBody(configuration: Configuration) -> some View {
        LumoriaButtonBody(configuration: configuration, hierarchy: hierarchy, size: size)
    }
}

// MARK: - Body

private struct LumoriaButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let hierarchy: LumoriaButtonHierarchy
    let size: LumoriaButtonSize

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .semibold))
            .tracking(-0.43)
            .foregroundStyle(labelColor)
            .opacity(labelOpacity)
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                if showBorder {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "D4D4D4"), lineWidth: 1)
                }
            }
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    // MARK: Label color

    private var labelColor: Color {
        switch hierarchy {
        case .primary, .danger:
            return .white
        case .secondary, .tertiary:
            return isEnabled ? .black : Color(hex: "D4D4D4")
        }
    }

    private var labelOpacity: Double {
        guard !isEnabled else { return 1.0 }
        switch hierarchy {
        case .primary, .danger:   return 0.3
        case .secondary, .tertiary: return 1.0
        }
    }

    // MARK: Background color

    private var backgroundColor: Color {
        if !isEnabled {
            switch hierarchy {
            case .primary:            return Color(hex: "D4D4D4")
            case .secondary, .tertiary: return .clear
            case .danger:             return Color(hex: "360003")
            }
        }
        if configuration.isPressed {
            switch hierarchy {
            case .primary:   return Color(hex: "404040")
            case .secondary: return Color.black.opacity(0.15)
            case .tertiary:  return Color.black.opacity(0.05)
            case .danger:    return Color(hex: "6B000B")
            }
        }
        switch hierarchy {
        case .primary:   return .black
        case .secondary: return Color.black.opacity(0.05)
        case .tertiary:  return .clear
        case .danger:    return Color(hex: "D94544")
        }
    }

    private var showBorder: Bool {
        !isEnabled && hierarchy == .secondary
    }
}

// MARK: - View convenience modifier

extension View {
    func lumoriaButtonStyle(
        _ hierarchy: LumoriaButtonHierarchy = .primary,
        size: LumoriaButtonSize = .large
    ) -> some View {
        buttonStyle(LumoriaButtonStyle(hierarchy: hierarchy, size: size))
    }
}

// MARK: - Color(hex:)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
