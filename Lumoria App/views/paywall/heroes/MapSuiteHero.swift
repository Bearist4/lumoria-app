//
//  MapSuiteHero.swift
//  Lumoria App
//
//  Curved dotted polyline with three pin dots — mirrors the look of
//  the actual MemoryMapView story-mode journey path so users
//  recognise the feature in the wild.
//

import SwiftUI

struct MapSuiteHero: View {

    private let accent = PaywallTrigger.Variant.mapSuite.accent

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                // Stylised map base — a soft rounded-corner field.
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(accent.opacity(0.08))

                // Faint grid lines for the "map" texture.
                Path { p in
                    let step: CGFloat = 24
                    var x: CGFloat = step
                    while x < w {
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: h))
                        x += step
                    }
                    var y: CGFloat = step
                    while y < h {
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                        y += step
                    }
                }
                .stroke(accent.opacity(0.15), lineWidth: 0.5)

                // Curved dotted journey path through three pin points.
                Path { p in
                    p.move(to: CGPoint(x: w * 0.15, y: h * 0.7))
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.5, y: h * 0.3),
                        control: CGPoint(x: w * 0.3, y: h * 0.05)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.85, y: h * 0.65),
                        control: CGPoint(x: w * 0.7, y: h * 0.05)
                    )
                }
                .stroke(
                    accent,
                    style: StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round,
                        dash: [2, 8]
                    )
                )

                // Three pin dots along the curve.
                pin(at: CGPoint(x: w * 0.15, y: h * 0.7))
                pin(at: CGPoint(x: w * 0.5,  y: h * 0.3))
                pin(at: CGPoint(x: w * 0.85, y: h * 0.65))
            }
        }
        .padding(.horizontal, 16)
    }

    private func pin(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 22, height: 22)
                .shadow(color: accent.opacity(0.4), radius: 6, y: 2)
            Circle()
                .fill(accent)
                .frame(width: 14, height: 14)
        }
        .position(point)
    }
}

#Preview {
    MapSuiteHero().frame(height: 200).padding(24)
}
