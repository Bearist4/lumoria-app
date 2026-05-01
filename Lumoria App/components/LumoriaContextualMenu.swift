//
//  LumoriaContextualMenu.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=575-12133
//

import SwiftUI

// MARK: - Item model

enum LumoriaMenuItemKind {
    case `default`
    case destructive
}

struct LumoriaMenuItem: Identifiable {
    let id = UUID()
    let title: LocalizedStringKey
    var kind: LumoriaMenuItemKind = .default
    /// Renders the row in semibold to indicate this option is already
    /// applied (e.g. the currently-selected sort).
    var isActive: Bool = false
    let action: () -> Void
}

// MARK: - Menu

/// Floating menu with a list of options. Destructive items render separated
/// by a divider at the bottom of the list.
struct LumoriaContextualMenu: View {

    let items: [LumoriaMenuItem]

    private var defaults: [LumoriaMenuItem] {
        items.filter { $0.kind == .default }
    }

    private var destructives: [LumoriaMenuItem] {
        items.filter { $0.kind == .destructive }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(defaults) { row($0) }

            if !destructives.isEmpty {
                Rectangle()
                    .fill(Color.Border.default)
                    .frame(height: 0.5)
                    .padding(.vertical, 6)

                ForEach(destructives) { row($0) }
            }
        }
        .padding(16)
        .frame(width: 249)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.Background.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.Border.default, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 14.2, x: -6, y: 10)
    }

    private func row(_ item: LumoriaMenuItem) -> some View {
        Button(action: item.action) {
            HStack {
                Text(item.title)
                    .font(item.isActive ? .body.weight(.semibold) : .body)
                    .foregroundStyle(
                        item.kind == .destructive
                            ? Color.Feedback.Danger.text
                            : Color.Text.primary
                    )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Trigger wrapper

/// Button that anchors a `LumoriaContextualMenu` to its own frame using a
/// transparent full-screen cover. Avoids the native popover arrow entirely —
/// the menu is positioned with captured anchor coordinates.
///
/// Action side effects (like presenting another sheet) are dispatched after
/// the cover dismisses so SwiftUI doesn't reject overlapping presentations.
struct LumoriaContextualMenuButton<Label: View>: View {

    let items: [LumoriaMenuItem]
    @ViewBuilder var label: () -> Label

    @State private var isShowing = false
    @State private var anchor: CGRect = .zero

    var body: some View {
        Button {
            present()
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.frame(in: .global), initial: true) { _, frame in
                        anchor = frame
                    }
            }
        )
        .fullScreenCover(isPresented: $isShowing) {
            MenuPresenter(
                anchor: anchor,
                items: items,
                onSelect: { handleSelection($0) },
                onDismiss: { dismiss() }
            )
            .presentationBackground(.clear)
        }
    }

    private func present() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { isShowing = true }
    }

    private func dismiss() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { isShowing = false }
    }

    private func handleSelection(_ item: LumoriaMenuItem) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            item.action()
        }
    }
}


// MARK: - Menu presenter (inside the fullScreenCover)

struct MenuPresenter: View {

    let anchor: CGRect
    let items: [LumoriaMenuItem]
    let onSelect: (LumoriaMenuItem) -> Void
    let onDismiss: () -> Void

    private let menuWidth: CGFloat = 249
    private let gap: CGFloat = 8
    private let edgeInset: CGFloat = 16

    @State private var didAppear = false

    var body: some View {
        // `anchor` is captured in the source view's global window
        // coord space. Inside the fullScreenCover, the content is
        // laid out from the window top (thanks to `.ignoresSafeArea`)
        // but SwiftUI still reports its origin with the top safe-area
        // inset baked in — so offsets that use raw `anchor.maxY` land
        // `safeAreaInsets.top` too low. Subtracting it brings the
        // menu back to a true 8pt gap.
        GeometryReader { rootProxy in
            let topInset = rootProxy.safeAreaInsets.top
            ZStack(alignment: .topLeading) {
                // Dismiss layer. Explicit Rectangle + .contentShape so
                // iOS doesn't skip hit-testing on a near-transparent
                // Color view.
                Rectangle()
                    .fill(Color.black.opacity(0.001))
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { close(then: onDismiss) }

                // The menu is conditionally rendered so SwiftUI runs
                // its insertion/removal transition. Both offset + opacity
                // ride the same spring driven by `value: didAppear`, so
                // the menu starts at -16pt above its resting position
                // (8pt below the trigger) at opacity 0 and animates
                // to its final offset and opacity 1 atomically. The
                // close transition runs the same animation in reverse.
                if didAppear {
                    LumoriaContextualMenu(items: wrapped)
                        .fixedSize()
                        .offset(
                            x: anchor.maxX - menuWidth,
                            y: anchor.maxY + gap - topInset
                        )
                        .transition(
                            .offset(y: -16).combined(with: .opacity)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(
                .spring(response: 0.32, dampingFraction: 0.86),
                value: didAppear
            )
        }
        .ignoresSafeArea()
        .onAppear { didAppear = true }
    }

    private func close(then action: @escaping () -> Void) {
        didAppear = false
        // Match the spring response above so the close motion finishes
        // before the fullScreenCover dismisses.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            action()
        }
    }

    private var wrapped: [LumoriaMenuItem] {
        items.map { item in
            LumoriaMenuItem(
                title: item.title,
                kind: item.kind,
                isActive: item.isActive
            ) {
                close(then: { onSelect(item) })
            }
        }
    }
}

// MARK: - Preview

#Preview("Contextual menu") {
    LumoriaContextualMenu(items: [
        .init(title: "Rename",        action: {}),
        .init(title: "Change color",  action: {}),
        .init(title: "Add location",  action: {}),
        .init(title: "Share",         action: {}),
        .init(title: "Duplicate",     action: {}),
        .init(title: "Pin",           action: {}),
        .init(title: "Archive",       action: {}),
        .init(title: "Delete", kind: .destructive, action: {}),
    ])
    .padding(40)
    .background(Color.Background.default)
}
