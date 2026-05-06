//
//  FreeTierLockOverlay.swift
//  Lumoria App
//
//  Visual + interaction layer for items that fall above the free-tier
//  cap (former early adopters who revoked their seat). The wrapped
//  content renders at 30 % opacity, a non-interactive black lock badge
//  sits top-right, and tap is intercepted to fire `onTap` instead of
//  the underlying NavigationLink — the host typically presents an
//  alert that explains why and how to regain access.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2155-173395 (memory)
//          figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2155-175460 (ticket)
//

import SwiftUI

struct FreeTierLockOverlay: ViewModifier {
    let isLocked: Bool
    let onTap: () -> Void

    func body(content: Content) -> some View {
        if isLocked {
            ZStack(alignment: .topTrailing) {
                content
                    .opacity(0.3)
                    .allowsHitTesting(false)
                lockBadge
                    .padding(12)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text("Locked"))
            .accessibilityHint(Text("Tap to learn how to unlock this item"))
        } else {
            content
        }
    }

    private var lockBadge: some View {
        Circle()
            .fill(Color.Button.Primary.Background.default)
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.Button.Primary.Label.default)
            }
    }
}

extension View {
    /// Wraps the receiver in a free-tier lock affordance: 30 % opacity,
    /// non-interactive lock badge, and an intercepted tap that fires
    /// `onTap` (typically presents the unlock alert). No-op when
    /// `isLocked` is false so unlocked items keep their normal
    /// NavigationLink behaviour.
    func freeTierLocked(_ isLocked: Bool, onTap: @escaping () -> Void) -> some View {
        modifier(FreeTierLockOverlay(isLocked: isLocked, onTap: onTap))
    }
}
