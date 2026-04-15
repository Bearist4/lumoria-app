//
//  LumoriaIconButton.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=304-4343
//

import SwiftUI

// MARK: - Size

enum LumoriaIconButtonSize {
    case large, medium, small

    var dimension: CGFloat {
        switch self {
        case .large:  return 48
        case .medium: return 40
        case .small:  return 32
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .large:  return 20
        case .medium: return 18
        case .small:  return 16
        }
    }

    var cornerRadius: CGFloat {
        // fully circular
        return dimension / 2
    }
}

// MARK: - Position (surface context)

enum LumoriaIconButtonPosition {
    /// Button sits on a light/transparent background
    case onBackground
    /// Button sits on a white/surface card
    case onSurface
}

// MARK: - Internal button style

private struct IconButtonStyle: ButtonStyle {
    let size: LumoriaIconButtonSize
    let position: LumoriaIconButtonPosition
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let bg = background(isPressed: configuration.isPressed)
        let fg = foregroundColor(isPressed: configuration.isPressed)

        configuration.label
            .font(.system(size: size.iconSize, weight: .semibold))
            .foregroundStyle(fg)
            .frame(width: size.dimension, height: size.dimension)
            .background(bg)
            .clipShape(Circle())
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }

    private func background(isPressed: Bool) -> Color {
        switch position {
        case .onBackground:
            if isPressed { return Color.black.opacity(0.15) }
            return Color.black.opacity(0.05)
        case .onSurface:
            if isPressed { return Color.white.opacity(0.85) }  // white + 0.15 overlay
            return .white
        }
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        .black
    }
}

// MARK: - LumoriaIconButton

struct LumoriaIconButton: View {
    let systemImage: String
    var size: LumoriaIconButtonSize = .large
    var position: LumoriaIconButtonPosition = .onBackground
    var isActive: Bool = false
    var showBadge: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(
            isActive
                ? AnyButtonStyle(ActiveIconButtonStyle(size: size))
                : AnyButtonStyle(IconButtonStyle(size: size, position: position))
        )
        .overlay(alignment: .topTrailing) {
            if showBadge {
                Circle()
                    .fill(Color(hex: "D94544"))
                    .frame(width: 10, height: 10)
                    .offset(x: 2, y: -2)
            }
        }
    }
}

// MARK: - Active style (icon white on black)

private struct ActiveIconButtonStyle: ButtonStyle {
    let size: LumoriaIconButtonSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.iconSize, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size.dimension, height: size.dimension)
            .background(configuration.isPressed ? Color(hex: "404040") : .black)
            .clipShape(Circle())
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Type-erased ButtonStyle (needed for conditional style switching)

private struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (ButtonStyle.Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

// MARK: - Preview

#Preview("Icon Button — All variants") {
    VStack(spacing: 24) {
        HStack(spacing: 12) {
            LumoriaIconButton(systemImage: "bell", size: .large, position: .onBackground, action: {})
            LumoriaIconButton(systemImage: "bell", size: .medium, position: .onBackground, action: {})
            LumoriaIconButton(systemImage: "bell", size: .small, position: .onBackground, action: {})
        }

        HStack(spacing: 12) {
            LumoriaIconButton(systemImage: "bell", size: .large, position: .onBackground, isActive: true, action: {})
            LumoriaIconButton(systemImage: "bell", size: .medium, position: .onBackground, isActive: true, action: {})
            LumoriaIconButton(systemImage: "bell", size: .small, position: .onBackground, isActive: true, action: {})
        }

        HStack(spacing: 12) {
            LumoriaIconButton(systemImage: "bell", size: .large, showBadge: true, action: {})
            LumoriaIconButton(systemImage: "bell", size: .medium, showBadge: true, action: {})
            LumoriaIconButton(systemImage: "bell", size: .small, showBadge: true, action: {})
        }

        HStack(spacing: 12) {
            LumoriaIconButton(systemImage: "xmark", size: .large, action: {})
            LumoriaIconButton(systemImage: "arrow.left", size: .large, action: {})
            LumoriaIconButton(systemImage: "plus", size: .large, action: {})
        }
        .padding()
        .background(Color.white)

    }
    .padding(24)
    .background(Color(hex: "F5F5F5"))
}
