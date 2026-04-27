//
//  TicketMapPin.swift
//  Lumoria App
//
//  Teardrop pin used to plot tickets on a map. A 47pt circle with a 4pt
//  background-colored ring and matching drop tail (white in light mode,
//  near-black in dark mode via `Color.Background.default`).
//
//  Two modes:
//    • Single ticket — solid category color + SF Symbol glyph.
//    • Cluster (≥2 tickets at the same coordinate) — a pie-chart of equal
//      slices (one per ticket) colored by each ticket's category, with
//      the count rendered in white at the center.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1652-47124
//

import SwiftUI

struct TicketMapPin: View {
    /// One entry per ticket sitting on this pin. Slice order matches this
    /// array. Count == 1 renders the single-ticket variant.
    let categories: [TicketCategoryStyle]

    private let circleSize: CGFloat = 47
    private let borderWidth: CGFloat = 4
    private let tailSize: CGFloat = 16
    /// How far the tail overlaps the circle's bottom so the shape reads as
    /// a single teardrop rather than a stacked circle + triangle.
    private let tailOverlap: CGFloat = 8

    init(categories: [TicketCategoryStyle]) {
        self.categories = categories.isEmpty ? [.plane] : categories
    }

    init(category: TicketCategoryStyle) {
        self.init(categories: [category])
    }

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
            background
            highlight
            label
        }
        .frame(width: circleSize, height: circleSize)
        .overlay(
            Circle().stroke(Color.Background.default, lineWidth: borderWidth)
        )
    }

    @ViewBuilder
    private var background: some View {
        if categories.count == 1 {
            Circle().fill(categories[0].backgroundColor)
        } else {
            ZStack {
                ForEach(Array(categories.enumerated()), id: \.offset) { idx, cat in
                    PieSlice(
                        startAngle: sliceAngle(at: idx),
                        endAngle: sliceAngle(at: idx + 1)
                    )
                    .fill(cat.backgroundColor)
                }
            }
            .clipShape(Circle())
        }
    }

    /// Subtle highlight so the disc reads with depth, matching the radial
    /// gradient on the Figma asset.
    private var highlight: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.25), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: circleSize * 0.7
                )
            )
    }

    @ViewBuilder
    private var label: some View {
        if categories.count == 1 {
            Image(systemName: categories[0].systemImage)
                .font(.title3)
                .foregroundStyle(categories[0].onColor)
        } else {
            Text("\(categories.count)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 0)
        }
    }

    private func sliceAngle(at index: Int) -> Angle {
        // Start at top (-90°) and sweep clockwise so slice #0 begins at 12 o'clock.
        let step = 360.0 / Double(categories.count)
        return .degrees(-90 + step * Double(index))
    }

    // MARK: - Tail

    private var tail: some View {
        DownTriangle()
            .fill(Color.Background.default)
            .frame(width: tailSize, height: tailSize)
            .zIndex(-1) // sits behind the circle's ring
    }
}

// MARK: - Pie slice

/// A wedge from center spanning `startAngle…endAngle`. Used to paint equal
/// slices of the cluster pin's circle background.
private struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var p = Path()
        p.move(to: center)
        p.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        p.closeSubpath()
        return p
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

#Preview("Single + clusters") {
    VStack(spacing: 32) {
        HStack(spacing: 24) {
            ForEach(TicketCategoryStyle.allCases) { c in
                TicketMapPin(category: c)
            }
        }

        HStack(spacing: 24) {
            TicketMapPin(categories: [.plane, .plane])
            TicketMapPin(categories: [.plane, .event])
            TicketMapPin(categories: [.plane, .train, .event])
            TicketMapPin(categories: [.plane, .train, .event, .food])
        }
    }
    .padding(48)
    .background(Color.Background.default)
}
