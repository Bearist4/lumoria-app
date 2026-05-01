//
//  EurovisionBackground.swift
//  Lumoria App
//
//  Background + decorative chrome shared between the horizontal and
//  vertical Eurovision templates. Each piece falls back to a code-drawn
//  default when its asset slot is empty so the template stays renderable
//  before any per-country PNG ships.
//

import SwiftUI
import UIKit

// MARK: - Per-country background

/// Renders `eurovision-bg-<cc>` as a full-bleed image when the asset
/// is present; falls back to a deep-blue swatch when the slot is still
/// empty. The decorative diagonal radial-glow stripes are baked into
/// the bg artwork itself (designer ships them per country) — the view
/// stays a thin wrapper.
struct EurovisionBackground: View {
    let assetName: String?
    let fallback: Color

    var body: some View {
        ZStack {
            if let name = assetName, UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback
                placeholderGlow
            }
        }
    }

    /// Swatch overlay shown when the per-country asset is missing — a
    /// pair of soft radial highlights that hint at the Eurovision-style
    /// stage glow without trying to fake a finished design.
    private var placeholderGlow: some View {
        ZStack {
            RadialGradient(
                colors: [Color.white.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 320
            )
            RadialGradient(
                colors: [Color(hex: "F72BBD").opacity(0.25), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 360
            )
        }
        .blendMode(.screen)
    }
}

// MARK: - Per-country logo

/// Renders `eurovision-logo-<cc>` (the country-specific composite of
/// the Eurovision heart + "EUROVISION" wordmark + country tag). Until
/// the artwork ships, falls back to a flag-emoji + country-name stack
/// so the user can still tell which country a ticket belongs to.
struct EurovisionLogo: View {
    let assetName: String?
    let country: EurovisionCountry?
    let displayName: String
    let maxHeight: CGFloat
    let maxWidth: CGFloat

    var body: some View {
        if let name = assetName, UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Text(country?.flagEmoji ?? "🇪🇺")
                .font(.system(size: maxHeight * 0.55))
            Text(displayName.isEmpty ? "Eurovision" : displayName)
                .font(.system(size: maxHeight * 0.13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
    }
}

// MARK: - "Grand Finale" pill

/// Top-of-ticket pill with a multi-stop gradient text fill. The Figma
/// uses a radial gradient on the horizontal layout and a 78°-linear
/// gradient on the vertical — `Variant` lets each call site pick the
/// right one without duplicating the swatch list.
struct EurovisionGrandFinalePill: View {

    enum Variant { case radial, linear }

    let scale: CGFloat
    let variant: Variant

    init(scale: CGFloat, style variant: Variant = .radial) {
        self.scale = scale
        self.variant = variant
    }

    var body: some View {
        Group {
            switch variant {
            case .radial:
                Text("Grand Finale").foregroundStyle(radialGradient)
            case .linear:
                Text("Grand Finale").foregroundStyle(linearGradient)
            }
        }
        .font(.system(size: 11 * scale, weight: .bold, design: .rounded))
        .lineLimit(1)
        .padding(.horizontal, 12 * scale)
        .padding(.vertical, 4 * scale)
        .background(
            Capsule().fill(Color.white)
        )
    }

    /// Four-stop gradient pulled straight from the Figma Custom paint:
    /// deep blue → cyan → magenta → red at 0 / 33 / 66 / 100 %.
    private var gradientStops: [Gradient.Stop] {
        [
            .init(color: Color(hex: "0305DF"), location: 0.00),
            .init(color: Color(hex: "90EDFC"), location: 0.33),
            .init(color: Color(hex: "F72BBD"), location: 0.66),
            .init(color: Color(hex: "F01647"), location: 1.00),
        ]
    }

    private var radialGradient: RadialGradient {
        RadialGradient(
            stops: gradientStops,
            center: .center,
            startRadius: 0,
            endRadius: 60 * scale
        )
    }

    /// Figma's vertical pill uses an ~78°-tilted linear sweep — close
    /// enough to a top-left → bottom-right diagonal that we model it
    /// with the simpler unit-point pair.
    private var linearGradient: LinearGradient {
        LinearGradient(
            stops: gradientStops,
            startPoint: UnitPoint(x: 0.0, y: 0.9),
            endPoint:   UnitPoint(x: 1.0, y: 0.1)
        )
    }
}
