//
//  TicketMapPin.swift
//  Lumoria App
//
//  Category-colored teardrop pin used to plot tickets on a map.
//  48pt × 60pt — a 47pt circle with a 4pt white ring and a white drop
//  tail below the circle. Icon + color pulled from `TicketCategoryStyle`.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1652-47124
//

import SwiftUI

struct TicketMapPin: View {
    let category: TicketCategoryStyle

    private let circleSize: CGFloat = 47
    private let borderWidth: CGFloat = 4
    private let tailSize: CGFloat = 16
    /// How far the tail overlaps the circle's bottom so the shape reads as
    /// a single teardrop rather than a stacked circle + triangle.
    private let tailOverlap: CGFloat = 8

    var body: some View {
        VStack(spacing: -tailOverlap) {
            circleFace
            tail
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.25), radius: 4.5, x: 0, y: 0)
    }

    // MARK: - Circle face

    private var circleFace: some View {
        ZStack {
            Circle()
                .fill(category.backgroundColor)

            // Subtle highlight so the disc reads with depth, matching the
            // radial gradient on the Figma asset.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.25), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: circleSize * 0.7
                    )
                )

            Image(systemName: category.systemImage)
                .font(.title3)
                .foregroundStyle(category.onColor)
        }
        .frame(width: circleSize, height: circleSize)
        .overlay(
            Circle().stroke(Color.white, lineWidth: borderWidth)
        )
    }

    // MARK: - Tail

    private var tail: some View {
        DownTriangle()
            .fill(Color.white)
            .frame(width: tailSize, height: tailSize)
            .zIndex(-1) // sits behind the circle's white ring
    }
}

/// Triangle pointing downward — base on top, apex at bottom center.
private struct DownTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 24) {
        ForEach(TicketCategoryStyle.allCases) { c in
            TicketMapPin(category: c)
        }
    }
    .padding(48)
    .background(Color.Background.default)
}
