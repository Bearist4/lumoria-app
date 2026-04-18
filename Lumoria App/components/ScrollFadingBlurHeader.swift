//
//  ScrollFadingBlurHeader.swift
//  Lumoria App
//
//  Scroll-aware counterpart to `StickyBlurHeader` — same visual
//  language (progressive blur + tint) but the overlay fades in as
//  content actually scrolls under it and stays fully invisible at
//  the top. Used by views presented as sheets (e.g. ticket detail
//  opened from a map pin) where a permanent dim band looks wrong.
//
//  Based on ProgressiveBlurHeader's `StickyBlurHeader`. Differs only
//  in opacity = f(scrollOffset).
//

import SwiftUI
import VariableBlur

private struct ScrollFadingHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollFadingBlurHeader<Header: View, Content: View>: View {

    private let maxBlurRadius: CGFloat
    private let fadeExtension: CGFloat
    private let tintOpacityTop: Double
    private let tintOpacityMiddle: Double
    /// Scroll offset (pt) at which the blur/tint layer reaches full
    /// opacity. Smaller value = crisper fade-in; larger = softer.
    private let fadeInDistance: CGFloat
    private let header: () -> Header
    private let content: () -> Content

    @State private var headerHeight: CGFloat = 76
    @State private var scrollOffset: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    init(
        maxBlurRadius: CGFloat = 8,
        fadeExtension: CGFloat = 48,
        tintOpacityTop: Double = 0.7,
        tintOpacityMiddle: Double = 0.5,
        fadeInDistance: CGFloat = 24,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.maxBlurRadius = maxBlurRadius
        self.fadeExtension = fadeExtension
        self.tintOpacityTop = tintOpacityTop
        self.tintOpacityMiddle = tintOpacityMiddle
        self.fadeInDistance = fadeInDistance
        self.header = header
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Layer 1: Scrollable content
            ScrollView {
                content()
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: headerHeight)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                // Normalize to 0 at rest: contentOffset.y starts negative
                // by the safe-area inset amount because the inner
                // `safeAreaInset(.top)` pushes content down. Adding back
                // `contentInsets.top` gives us "pixels scrolled past the
                // rest position", so even a 1pt drag starts fading the
                // blur in — instead of waiting until the header area has
                // been fully scrolled through.
                geo.contentOffset.y + geo.contentInsets.top
            } action: { _, newValue in
                scrollOffset = newValue
            }

            // Layer 2: Progressive blur + tint (fades with scroll)
            let totalHeight = headerHeight + fadeExtension
            let blurOpacity = min(1.0, max(0.0, Double(scrollOffset) / Double(fadeInDistance)))

            VariableBlurView(
                maxBlurRadius: maxBlurRadius,
                direction: .blurredTopClearBottom
            )
            .overlay {
                // Clamp the middle stop's location inside (0, 1) so a
                // zero / small `totalHeight` during the first layout
                // pass doesn't push it past the trailing stop and
                // trip SwiftUI's "stops must be ordered" warning.
                let midLocation = min(0.999, max(0.001, 90 / max(totalHeight, 1)))
                LinearGradient(stops: [
                    .init(color: fadeTint.opacity(tintOpacityTop), location: 0),
                    .init(color: fadeTint.opacity(tintOpacityMiddle), location: midLocation),
                    .init(color: fadeTint.opacity(0), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
            .frame(height: totalHeight)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .opacity(blurOpacity)

            // Layer 3: Header — floats above blur
            header()
                .overlay {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollFadingHeaderHeightKey.self,
                            value: geo.size.height
                        )
                    }
                }
        }
        .onPreferenceChange(ScrollFadingHeaderHeightKey.self) { headerHeight = $0 }
    }

    private var fadeTint: Color {
        colorScheme == .dark ? .black : .white
    }
}
