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
    /// Button sits on a light/transparent background — semi-transparent
    /// black fill, black icon.
    case onBackground
    /// Button sits on a white/surface card — white fill, black icon.
    case onSurface
    /// Button sits on a dark background (e.g. a full-screen photo sheet)
    /// — semi-transparent white fill, white icon.
    case onDark
    /// Affirmative action button — solid green fill, white icon.
    case success
    /// Destructive action button — solid red fill, white icon. Reuses
    /// `Button.Danger.*` tokens so the colour stays in lockstep with
    /// the destructive primary button.
    case danger
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
            return isPressed
                ? Color.IconButton.OnBackground.Background.pressed
                : Color.IconButton.OnBackground.Background.default
        case .onSurface:
            return isPressed
                ? Color.IconButton.OnSurface.Background.pressed
                : Color.IconButton.OnSurface.Background.default
        case .onDark:
            return isPressed
                ? Color.IconButton.OnDark.Background.pressed
                : Color.IconButton.OnDark.Background.default
        case .success:
            return isPressed
                ? Color.IconButton.Success.Background.pressed
                : Color.IconButton.Success.Background.default
        case .danger:
            return isPressed
                ? Color.Button.Danger.Background.pressed
                : Color.Button.Danger.Background.default
        }
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        switch position {
        case .onBackground: return Color.IconButton.OnBackground.Content.default
        case .onSurface:    return Color.IconButton.OnSurface.Content.default
        case .onDark:       return Color.IconButton.OnDark.Content.default
        case .success:      return Color.IconButton.Success.Content.default
        case .danger:       return Color.Button.Danger.Label.default
        }
    }
}

// MARK: - LumoriaIconButton

struct LumoriaIconButton: View {
    let systemImage: String
    var size: LumoriaIconButtonSize = .large
    var position: LumoriaIconButtonPosition = .onBackground
    var isActive: Bool = false
    var showBadge: Bool = false
    /// When non-nil and > 0 the badge renders as a pill with the
    /// count instead of the 10pt dot. Falls back to the dot when
    /// `showBadge` is true and `badgeCount` is nil or 0.
    var badgeCount: Int? = nil
    /// Nil = render visual only (no Button). Useful when the button
    /// sits inside another tappable container (e.g. a contextual menu
    /// trigger) and nesting Buttons would swallow the outer tap.
    let action: (() -> Void)?
    /// When non-nil the icon button renders as a menu trigger: tap
    /// opens a Lumoria contextual menu anchored exactly 8pt below
    /// this button, every time. `action` is ignored when a menu is
    /// provided.
    let menuItems: [LumoriaMenuItem]?

    @State private var isMenuShowing: Bool = false
    @State private var anchor: CGRect = .zero

    init(
        systemImage: String,
        size: LumoriaIconButtonSize = .large,
        position: LumoriaIconButtonPosition = .onBackground,
        isActive: Bool = false,
        showBadge: Bool = false,
        badgeCount: Int? = nil,
        action: (() -> Void)? = nil,
        menuItems: [LumoriaMenuItem]? = nil
    ) {
        self.systemImage = systemImage
        self.size = size
        self.position = position
        self.isActive = isActive
        self.showBadge = showBadge
        self.badgeCount = badgeCount
        self.action = action
        self.menuItems = menuItems
    }

    var body: some View {
        Group {
            if let menuItems {
                menuTrigger(items: menuItems)
            } else if let action {
                Button(action: action) {
                    Image(systemName: systemImage)
                }
                .buttonStyle(
                    isActive
                        ? AnyButtonStyle(ActiveIconButtonStyle(size: size))
                        : AnyButtonStyle(IconButtonStyle(size: size, position: position))
                )
                .overlay(alignment: .topTrailing) {
                    if shouldShowBadge { badge }
                }
            } else {
                visualOnly
            }
        }
    }

    // MARK: - Menu trigger

    /// Button-styled trigger that presents the Lumoria contextual menu
    /// via the shared `MenuPresenter`. The presenter hosts the dim
    /// layer that catches tap-outside, the slide-down + dissolve
    /// animation, and the anchor-based positioning. Dismissal: tap an
    /// item, tap outside, or tap the icon again.
    @ViewBuilder
    private func menuTrigger(items: [LumoriaMenuItem]) -> some View {
        Button {
            present()
        } label: {
            Image(systemName: systemImage)
        }
        .buttonStyle(
            (isActive || isMenuShowing)
                ? AnyButtonStyle(ActiveIconButtonStyle(size: size))
                : AnyButtonStyle(IconButtonStyle(size: size, position: position))
        )
        .overlay(alignment: .topTrailing) {
            if shouldShowBadge { badge }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.frame(in: .global), initial: true) { _, frame in
                        anchor = frame
                    }
            }
        )
        .fullScreenCover(isPresented: $isMenuShowing) {
            MenuPresenter(
                anchor: anchor,
                items: items,
                onSelect: { item in
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        item.action()
                    }
                },
                onDismiss: { dismiss() }
            )
            .presentationBackground(.clear)
        }
    }

    private func present() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { isMenuShowing = true }
    }

    private func dismiss() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { isMenuShowing = false }
    }

    // MARK: - Visual-only rendering

    private var visualOnly: some View {
        Image(systemName: systemImage)
            .font(.system(size: size.iconSize, weight: .semibold))
            .foregroundStyle(visualForeground)
            .frame(width: size.dimension, height: size.dimension)
            .background(visualBackground)
            .clipShape(Circle())
            .overlay(alignment: .topTrailing) {
                if shouldShowBadge { badge }
            }
    }

    // MARK: - Visual-only tokens (mirror IconButtonStyle at rest)

    private var visualBackground: Color {
        if isActive { return Color.IconButton.OnBackground.Background.active }
        switch position {
        case .onBackground: return Color.IconButton.OnBackground.Background.default
        case .onSurface:    return Color.IconButton.OnSurface.Background.default
        case .onDark:       return Color.IconButton.OnDark.Background.default
        case .success:      return Color.IconButton.Success.Background.default
        case .danger:       return Color.Button.Danger.Background.default
        }
    }

    private var visualForeground: Color {
        if isActive { return Color.IconButton.OnBackground.Content.active }
        switch position {
        case .onBackground: return Color.IconButton.OnBackground.Content.default
        case .onSurface:    return Color.IconButton.OnSurface.Content.default
        case .onDark:       return Color.IconButton.OnDark.Content.default
        case .success:      return Color.IconButton.Success.Content.default
        case .danger:       return Color.Button.Danger.Label.default
        }
    }

    private var shouldShowBadge: Bool {
        showBadge || (badgeCount ?? 0) > 0
    }

    @ViewBuilder
    private var badge: some View {
        if let count = badgeCount, count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .frame(minWidth: 16, minHeight: 16)
                .background(Capsule().fill(Color.Feedback.Danger.icon))
                .offset(x: 4, y: -4)
        } else {
            Circle()
                .fill(Color.Feedback.Danger.icon)
                .frame(width: 10, height: 10)
                .offset(x: 2, y: -2)
        }
    }
}

// MARK: - Active style (icon white on black)

private struct ActiveIconButtonStyle: ButtonStyle {
    let size: LumoriaIconButtonSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.iconSize, weight: .semibold))
            .foregroundStyle(Color.Button.Primary.Label.default)
            .frame(width: size.dimension, height: size.dimension)
            .background(
                configuration.isPressed
                    ? Color.Button.Primary.Background.pressed
                    : Color.Button.Primary.Background.default
            )
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
