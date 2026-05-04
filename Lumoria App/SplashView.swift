//
//  SplashView.swift
//  Lumoria App
//
//  Cold-start intro. Four brand colour bars bounce in from the
//  bottom (blue → orange → yellow → pink), the 7-point star reveals
//  with a cream "ticket-perforation" halo and rotates one full turn
//  back to upright, then the entire composition morphs continuously
//  into the logomark — frame shrinks to 137pt, bars retract from
//  full-screen to a half-height band, cream backdrop emerges above
//  — landing at the exact slot LandingView paints. Total ~3 s.
//

import SwiftUI

struct SplashView: View {
    /// When false, skip the bouncing-bars + morph and just show
    /// the static app icon for a brief beat — used on cold starts
    /// for already-authenticated users where the morph would land
    /// on a screen (ContentView) that doesn't carry a logomark.
    var animated: Bool = true
    var onFinish: () -> Void = {}

    @Environment(\.brandSlug) private var brandSlug

    @State private var blueIn = false
    @State private var orangeIn = false
    @State private var yellowIn = false
    @State private var pinkIn = false

    @State private var starVisible = false
    @State private var starRotation: Double = 0

    /// 0 = full-screen bar layout, 1 = 137pt logomark layout.
    /// Drives every geometric morph in lockstep so there's no jump.
    @State private var compressProgress: CGFloat = 0

    @State private var showRealLogomark = false

    private let creamC   = Color(red: 0xFF/255, green: 0xFC/255, blue: 0xF0/255)
    private let blueC    = Color(red: 0x57/255, green: 0xB7/255, blue: 0xF5/255)
    private let orangeC  = Color(red: 0xFF/255, green: 0xA9/255, blue: 0x6C/255)
    private let yellowC  = Color(red: 0xFD/255, green: 0xDC/255, blue: 0x51/255)
    private let pinkC    = Color(red: 0xFF/255, green: 0x9C/255, blue: 0xCC/255)

    private let logomarkSize: CGFloat = 137
    private let logomarkCornerRadius: CGFloat = 38
    /// Outer top corner radius on the blue + pink bars — matches
    /// the iPhone display radius. Held constant through the entire
    /// animation so the rounded corner never disappears.
    private let outerBarTopRadius: CGFloat = 28
    /// Star size at icon state. Matches the canonical app-icon SVG
    /// (58pt star path inside a 136pt squircle).
    private let iconStarSize: CGFloat = 58
    /// Bar fill height at icon state — bottom-aligned, ≈ 61pt
    /// inside the 137pt frame. Tuned so the bar height at the end
    /// of the morph matches the asset PDF (8pt shorter than the
    /// raw 50% split).
    private let iconBarFraction: CGFloat = 61.0 / 137.0
    /// Cream halo size as a multiple of the black star — produces
    /// the same star-shaped negative space the official paths cut
    /// into the orange + yellow bars.
    private let haloScale: CGFloat = 1.30

    var body: some View {
        if animated {
            animatedBody
        } else {
            staticBody
        }
    }

    private var staticBody: some View {
        ZStack {
            Color.Background.default.ignoresSafeArea()
            Image("brand/\(brandSlug)/logomark")
                .resizable()
                .scaledToFit()
                .frame(width: logomarkSize, height: logomarkSize)
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .milliseconds(600))
            onFinish()
        }
    }

    private var animatedBody: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let logomarkY = logomarkCenterY(in: h)

            // Single morph parameter drives every dimension below.
            let p = compressProgress
            let frameW = lerp(w, logomarkSize, p)
            let frameH = lerp(h, logomarkSize, p)
            let centerY = lerp(h/2, logomarkY, p)
            // Corner radius eases in faster than the linear morph so
            // the bars pick up the squircle curve while they're still
            // shrinking, rather than snapping rounded only at the end.
            // Capped at half the smaller dimension so it never folds
            // into a pill.
            let cornerCap = min(frameW, frameH) / 2
            let cornerR = min(cornerCap, lerp(0, logomarkCornerRadius, pow(p, 0.5)))
            let barFraction = lerp(1.0, iconBarFraction, p)
            let barTopRadius = outerBarTopRadius
            // Star size scales smoothly from full-screen "step 5"
            // size (≈37 % of screen width) down to 58pt.
            let starSize = lerp(min(w, h) * 0.36, iconStarSize, p)

            ZStack {
                Color.Background.default.ignoresSafeArea()

                ZStack {
                    // Cream squircle backdrop — visible only where
                    // bars don't cover it (top portion at icon state).
                    Rectangle().fill(creamC)

                    // Four colour bars, bottom-aligned. Each bar
                    // owns its bounce-in via scaleY from anchor .bottom.
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        HStack(spacing: 0) {
                            barColumn(blueC,   show: blueIn,   topLeading: barTopRadius, topTrailing: 0)
                            barColumn(orangeC, show: orangeIn, topLeading: 0,            topTrailing: 0)
                            barColumn(yellowC, show: yellowIn, topLeading: 0,            topTrailing: 0)
                            barColumn(pinkC,   show: pinkIn,   topLeading: 0,            topTrailing: barTopRadius)
                        }
                        .frame(height: frameH * barFraction)
                    }

                    // Cream halo + black star rotate together so the
                    // ticket-perforation cutout always tracks the
                    // star, then both land upright at the icon
                    // orientation.
                    ZStack {
                        SevenPointStar()
                            .fill(creamC)
                            .frame(width: starSize * haloScale, height: starSize * haloScale)
                        SevenPointStar()
                            .fill(Color.black)
                            .frame(width: starSize, height: starSize)
                    }
                    .scaleEffect(starVisible ? 1 : 0.3)
                    .rotationEffect(.degrees(starRotation))
                    .opacity(starVisible ? 1 : 0)
                }
                .frame(width: frameW, height: frameH)
                .clipShape(RoundedRectangle(cornerRadius: cornerR, style: .continuous))
                .position(x: w/2, y: centerY)
                .opacity(showRealLogomark ? 0 : 1)

                // Pixel-perfect hand-off to the asset for the final
                // frame — quick crossfade hides any sub-pixel drift.
                Image("brand/\(brandSlug)/logomark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: logomarkSize, height: logomarkSize)
                    .position(x: w/2, y: logomarkY)
                    .opacity(showRealLogomark ? 1 : 0)
            }
            .task { runSequence() }
        }
        .ignoresSafeArea()
    }

    /// Mirrors LandingView's VStack: flexible top spacer + fixed
    /// bottom block (logomark 137 + spacer 54 + logo 90 + headline ≈
    /// 82 + bottom spacer 200). Returns the Y centre of the logomark
    /// slot so the morph lands exactly where LandingView paints its
    /// logomark.
    private func logomarkCenterY(in h: CGFloat) -> CGFloat {
        let bottomBlock: CGFloat = 137 + 54 + 90 + 82 + 200
        return max(h/2, h - bottomBlock + 137/2)
    }

    private func barColumn(_ color: Color, show: Bool, topLeading: CGFloat, topTrailing: CGFloat) -> some View {
        Color.clear.overlay(alignment: .bottom) {
            UnevenRoundedRectangle(cornerRadii: .init(
                topLeading: topLeading,
                bottomLeading: 0,
                bottomTrailing: 0,
                topTrailing: topTrailing
            ), style: .continuous)
                .fill(color)
                .scaleEffect(y: show ? 1 : 0.001, anchor: .bottom)
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func runSequence() {
        Task { @MainActor in
            let bounce = Animation.spring(response: 0.42, dampingFraction: 0.55)

            // Bars bounce in (t = 80 → 560 ms).
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(bounce) { blueIn = true }
            try? await Task.sleep(for: .milliseconds(160))
            withAnimation(bounce) { orangeIn = true }
            try? await Task.sleep(for: .milliseconds(160))
            withAnimation(bounce) { yellowIn = true }
            try? await Task.sleep(for: .milliseconds(160))
            withAnimation(bounce) { pinkIn = true }

            // Star + halo reveal, star starts spinning back to upright
            // (t = 760 → 2160 ms).
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                starVisible = true
            }
            withAnimation(.easeInOut(duration: 1.4)) {
                starRotation = 360
            }

            // Continuous morph from full-screen layout to icon layout.
            // Spring is slow + over-damped so it lands cleanly without
            // overshoot (t = 1040 → ≈ 2240 ms).
            try? await Task.sleep(for: .milliseconds(280))
            withAnimation(.spring(response: 1.15, dampingFraction: 0.92)) {
                compressProgress = 1
            }

            // Crossfade to the asset image for pixel-perfect parity
            // with LandingView's logomark (t ≈ 2280 → 2480 ms).
            try? await Task.sleep(for: .milliseconds(1240))
            withAnimation(.easeInOut(duration: 0.2)) {
                showRealLogomark = true
            }

            // Hold on the final logomark, then hand off to the
            // underlying root view. Total ≈ 3000 ms.
            try? await Task.sleep(for: .milliseconds(520))
            onFinish()
        }
    }
}

#Preview {
    SplashView()
}
