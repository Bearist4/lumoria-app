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

enum OnboardingOverlayStyle {
    /// Full-screen dim with a rounded-rect cutout around the anchor.
    /// Tip card is pinned to the bottom of the screen.
    case cutout
    /// No dim, no blocking. Only the tip card is rendered at the bottom
    /// of the screen — used for screens where every element needs to
    /// remain interactive (e.g. ticket form).
    case banner
}

struct OnboardingOverlayModifier: ViewModifier {
    let step: OnboardingStep
    @ObservedObject var coordinator: OnboardingCoordinator
    let anchorID: String?
    let tip: OnboardingTipCopy
    var style: OnboardingOverlayStyle = .cutout
    /// Extra activation gate beyond `coordinator.currentStep == step`.
    /// Used by banner-style overlays whose host screen is shared across
    /// several funnel steps — e.g. the `fillInfo` banner sits on the
    /// funnel view, but should only render once the funnel reaches the
    /// `.form` inner step.
    var additionalActivation: Bool = true

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(OnboardingAnchorKey.self) { anchors in
            ZStack {
                if coordinator.currentStep == step && additionalActivation {
                    GeometryReader { proxy in
                        let targetRect: CGRect? = {
                            guard let id = anchorID, let anchor = anchors[id] else { return nil }
                            return proxy[anchor]
                        }()
                        overlay(
                            targetRect: targetRect,
                            fullSize: proxy.size
                        )
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
            // Drives the implicit fade for the overlay's appear /
            // disappear transition. Without an explicit `.animation`
            // here, SwiftUI doesn't always animate the if-condition flip.
            .animation(.easeInOut(duration: 0.25),
                       value: coordinator.currentStep == step && additionalActivation)
        }
    }

    // MARK: - Composition

    @ViewBuilder
    private func overlay(targetRect: CGRect?, fullSize: CGSize) -> some View {
        switch style {
        case .cutout:
            cutoutLayer(targetRect: targetRect, fullSize: fullSize)
        case .banner:
            bannerLayer(fullSize: fullSize)
        }
    }

    @ViewBuilder
    private func cutoutLayer(targetRect: CGRect?, fullSize: CGSize) -> some View {
        if let targetRect {
            let padded = targetRect.insetBy(dx: -8, dy: -8)
            let cornerRadius: CGFloat = 18

            ZStack(alignment: .topLeading) {
                HoleShape(hole: padded, cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
                    .contentShape(
                        HoleShape(hole: padded, cornerRadius: cornerRadius),
                        eoFill: true
                    )
                    .onTapGesture { /* swallow off-target taps */ }

                OnboardingTipCard(copy: tip) {
                    coordinator.showLeaveAlert = true
                }
                .offset(tipOffset(padded: padded, fullSize: fullSize))
                .allowsHitTesting(true)
                .modifier(DelayedFadeIn(delay: 0.25))
            }
            .frame(width: fullSize.width, height: fullSize.height)
        }
    }

    @ViewBuilder
    private func bannerLayer(fullSize: CGSize) -> some View {
        ZStack {
            Color.clear
            OnboardingTipCard(copy: tip) {
                coordinator.showLeaveAlert = true
            }
            .position(bottomTipCenter(fullSize: fullSize))
            .allowsHitTesting(true)
            .modifier(DelayedFadeIn(delay: 0.25))
        }
        .frame(width: fullSize.width, height: fullSize.height)
        .allowsHitTesting(true)
    }

    /// Pin the tip to the bottom of the screen so it never sandwiches
    /// between target items or obscures selectable content. Clears the
    /// home-indicator area + a comfortable gap above.
    private func bottomTipCenter(fullSize: CGSize) -> CGPoint {
        let tipHeightGuess: CGFloat = 140
        let bottomMargin: CGFloat = 60
        let y = fullSize.height - bottomMargin - tipHeightGuess / 2
        let x = fullSize.width / 2
        return CGPoint(x: x, y: y)
    }

    /// Position tip 16pt below the cutout when there's room; otherwise
    /// place it above. Horizontal side follows the cutout: left-align
    /// when the cutout sits in the left half of the screen,
    /// right-align when it sits in the right half. A wide cutout (>60%
    /// of screen width) centers the tip instead, since either edge
    /// would look detached.
    private func tipOffset(padded: CGRect, fullSize: CGSize) -> CGSize {
        let tipWidth: CGFloat = 302
        let tipHeightGuess: CGFloat = 160
        let horizontalInset: CGFloat = 16
        let verticalGap: CGFloat = 16
        // Reserve room below the tip for the home indicator + a
        // comfortable bottom margin so the tip doesn't kiss the edge.
        let bottomReserve: CGFloat = 60
        let isLargeArea = padded.width > fullSize.width * 0.6
        let cutoutOnRight = padded.midX > fullSize.width / 2
        let belowFits = padded.maxY + verticalGap + tipHeightGuess
            <= fullSize.height - bottomReserve

        let x: CGFloat
        if isLargeArea {
            x = (fullSize.width - tipWidth) / 2
        } else if cutoutOnRight {
            x = max(horizontalInset, fullSize.width - horizontalInset - tipWidth)
        } else {
            x = horizontalInset
        }
        let y: CGFloat = belowFits
            ? padded.maxY + verticalGap
            : max(horizontalInset, padded.minY - verticalGap - tipHeightGuess)
        return CGSize(width: x, height: y)
    }
}

/// Fades a view in once after a delay, on first appear. Used by the
/// onboarding tip cards so they dissolve in 0.25s after the dim layer
/// has finished its own fade-in.
private struct DelayedFadeIn: ViewModifier {
    let delay: Double
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25).delay(delay)) {
                    visible = true
                }
            }
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
    ///
    /// `gatedBy` adds a second activation predicate — useful when the
    /// overlay should auto-dismiss based on app state (e.g. once the
    /// targeted field has a value) without advancing the onboarding
    /// step. Defaults to `true` so existing callers behave as before.
    func onboardingOverlay(
        step: OnboardingStep,
        coordinator: OnboardingCoordinator,
        anchorID: String,
        tip: OnboardingTipCopy,
        gatedBy: Bool = true
    ) -> some View {
        modifier(OnboardingOverlayModifier(
            step: step,
            coordinator: coordinator,
            anchorID: anchorID,
            tip: tip,
            style: .cutout,
            additionalActivation: gatedBy
        ))
    }

    /// Tip-only variant — no dim, no cutout, no blocking. Use when the
    /// whole host screen needs to remain interactive (e.g. the ticket
    /// form where the user scrolls + taps many fields).
    ///
    /// `gatedBy` lets a host that's shared across several inner steps
    /// (e.g. the new-ticket funnel) restrict the banner to one of them.
    /// Defaults to `true` so existing callers behave as before.
    func onboardingBannerOverlay(
        step: OnboardingStep,
        coordinator: OnboardingCoordinator,
        tip: OnboardingTipCopy,
        gatedBy: Bool = true
    ) -> some View {
        modifier(OnboardingOverlayModifier(
            step: step,
            coordinator: coordinator,
            anchorID: nil,
            tip: tip,
            style: .banner,
            additionalActivation: gatedBy
        ))
    }
}
