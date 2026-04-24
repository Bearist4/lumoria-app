//
//  OnboardingOverlay.swift
//  Lumoria App
//
//  Dim-and-cutout modifier applied to any view that hosts an onboarding
//  step. Renders only when `coordinator.currentStep == step`. Pass-through
//  cutout: taps inside the hole reach the underlying control natively,
//  taps elsewhere are swallowed by the dim layer. X on the tip card opens
//  the leave-alert via coordinator.showLeaveAlert.
//

import SwiftUI

struct OnboardingOverlayModifier: ViewModifier {
    let step: OnboardingStep
    @ObservedObject var coordinator: OnboardingCoordinator
    let anchorID: String
    let tip: OnboardingTipCopy

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(OnboardingAnchorKey.self) { anchors in
            if coordinator.currentStep == step,
               let anchor = anchors[anchorID] {
                GeometryReader { proxy in
                    overlay(rect: proxy[anchor], fullSize: proxy.size)
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
    }

    // MARK: - Overlay composition

    @ViewBuilder
    private func overlay(rect targetRect: CGRect, fullSize: CGSize) -> some View {
        let padded = targetRect.insetBy(dx: -8, dy: -8)
        let cornerRadius: CGFloat = 18

        ZStack {
            // Hit-testable dim layer with a hole cut out via even-odd fill.
            // Taps inside the hole pass through to the underlying control;
            // taps outside are swallowed.
            HoleShape(hole: padded, cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
                .contentShape(
                    HoleShape(hole: padded, cornerRadius: cornerRadius),
                    eoFill: true
                )
                .onTapGesture {
                    // Swallow taps on the dim area so the user can't interact
                    // with off-target UI. Inside the hole this gesture is not
                    // hit-tested (contentShape excludes the rounded rect).
                }

            OnboardingTipCard(copy: tip) {
                coordinator.showLeaveAlert = true
            }
            .position(tipCenter(fullSize: fullSize, target: padded))
            .allowsHitTesting(true)
        }
        .frame(width: fullSize.width, height: fullSize.height)
    }

    private func tipCenter(fullSize: CGSize, target: CGRect) -> CGPoint {
        let tipHeight: CGFloat = 110
        let tipWidth: CGFloat = 300
        let spacing: CGFloat = 16
        let belowY = target.maxY + spacing + tipHeight / 2
        let aboveY = target.minY - spacing - tipHeight / 2
        let preferBelow = belowY + tipHeight / 2 < fullSize.height
        let y = preferBelow ? belowY : max(tipHeight / 2 + 40, aboveY)
        let x = min(max(target.midX, 16 + tipWidth / 2),
                    fullSize.width - 16 - tipWidth / 2)
        return CGPoint(x: x, y: y)
    }
}

/// A full-screen rect with a rounded-rect hole. Used both as the fill
/// shape and as the content shape (hit test) via even-odd rule, so taps
/// inside the hole don't register on this view.
private struct HoleShape: Shape {
    let hole: CGRect
    let cornerRadius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(rect)
        p.addRoundedRect(
            in: hole,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return p
    }
}

extension View {
    /// Attaches an onboarding overlay that activates when
    /// `coordinator.currentStep == step` and cuts around the view tagged
    /// with `.onboardingAnchor(anchorID)`.
    func onboardingOverlay(
        step: OnboardingStep,
        coordinator: OnboardingCoordinator,
        anchorID: String,
        tip: OnboardingTipCopy
    ) -> some View {
        modifier(OnboardingOverlayModifier(
            step: step,
            coordinator: coordinator,
            anchorID: anchorID,
            tip: tip
        ))
    }
}
