//
//  OnboardingAnchorKey.swift
//  Lumoria App
//
//  PreferenceKey that bubbles target-element bounds up to the overlay
//  modifier, which resolves them via GeometryReader into a CGRect for
//  positioning the cutout and tip card.
//

import SwiftUI

struct OnboardingAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>],
                       nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    /// Registers this view's bounds under `id` so a sibling
    /// `.onboardingOverlay(...)` modifier can cut out around it.
    func onboardingAnchor(_ id: String) -> some View {
        anchorPreference(key: OnboardingAnchorKey.self,
                         value: .bounds) { [id: $0] }
    }
}
