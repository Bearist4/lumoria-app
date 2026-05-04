//
//  ColorTarget.swift
//  Lumoria App
//
//  Decorative annotation paired with the style step's preview tile —
//  a `ColorPill` plus a leader line that points at the recolorable
//  region. The `direction` controls where the line emerges from the
//  pill (the leader is drawn on the side opposite the pill).
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2102-96276
//

import SwiftUI

struct ColorTarget: View {

    enum Direction {
        case top      // pill above, leader points down
        case bottom   // pill below, leader points up
        case left     // pill on the left, leader points right
        case right    // pill on the right, leader points left
    }

    let color: Color
    let label: String
    let direction: Direction
    /// Pixel length of the leader stroke. Defaults to Figma's 41pt;
    /// the style-step's preview tile passes a longer value when it
    /// needs to push the pill out of the ticket area into the card
    /// gutter.
    var leaderLength: CGFloat = 41

    var body: some View {
        switch direction {
        case .top:    verticalLayout(pillFirst: true)
        case .bottom: verticalLayout(pillFirst: false)
        case .left:   horizontalLayout(pillFirst: true)
        case .right:  horizontalLayout(pillFirst: false)
        }
    }

    // MARK: - Layouts

    private func verticalLayout(pillFirst: Bool) -> some View {
        VStack(spacing: 0) {
            if pillFirst {
                pill
                leader(vertical: true)
            } else {
                leader(vertical: true)
                pill
            }
        }
    }

    private func horizontalLayout(pillFirst: Bool) -> some View {
        HStack(spacing: 0) {
            if pillFirst {
                pill
                leader(vertical: false)
            } else {
                leader(vertical: false)
                pill
            }
        }
    }

    // MARK: - Pieces

    private var pill: ColorPill {
        ColorPill(color: color, label: label)
    }

    /// Hairline leader with a small knob (4pt dot) at the end touching
    /// the referenced element — never on the pill side. Direction
    /// drives the offset:
    ///
    ///   - `.top`    pill above element   → leader runs down → knob bottom
    ///   - `.bottom` pill below element   → leader runs up   → knob top
    ///   - `.left`   pill left of element → leader runs right → knob right
    ///   - `.right`  pill right of element → leader runs left  → knob left
    private func leader(vertical: Bool) -> some View {
        ZStack {
            if vertical {
                Rectangle()
                    .fill(Color.Border.default)
                    .frame(width: 1, height: leaderLength)
            } else {
                Rectangle()
                    .fill(Color.Border.default)
                    .frame(width: leaderLength, height: 1)
            }
            // 4pt knob anchored at the leader's far end (the element
            // side, not the pill side). The HStack/VStack layouts
            // place the leader on the side opposite the pill, so for
            // `.left` the leader's right edge touches the element →
            // knob sits at +x. Symmetric for the other directions.
            Circle()
                .fill(Color.Border.default)
                .frame(width: 4, height: 4)
                .offset(
                    x: vertical ? 0 : (leaderLength / 2 - 2) * (direction == .left ? 1 : -1),
                    y: vertical ? (leaderLength / 2 - 2) * (direction == .top ? 1 : -1) : 0
                )
        }
    }
}

// MARK: - Preview

#Preview("All directions") {
    ZStack {
        Color.Background.elevated.ignoresSafeArea()

        VStack(spacing: 32) {
            HStack(spacing: 32) {
                ColorTarget(color: Color(hex: "D94544"), label: "accent",    direction: .top)
                ColorTarget(color: Color(hex: "D94544"), label: "accent",    direction: .bottom)
            }
            HStack(spacing: 32) {
                ColorTarget(color: Color(hex: "FFFCF0"), label: "background", direction: .left)
                ColorTarget(color: Color(hex: "FFFCF0"), label: "background", direction: .right)
            }
        }
        .padding(24)
    }
}
