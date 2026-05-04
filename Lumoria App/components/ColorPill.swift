//
//  ColorPill.swift
//  Lumoria App
//
//  Small inline pill that pairs a 12pt circular color swatch with an
//  11pt label. Used as the head of `ColorTarget` and anywhere we want
//  to caption a color in a compact row.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2102-96270
//

import SwiftUI

struct ColorPill: View {

    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.Text.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.Background.elevated)
        )
        .overlay(
            Capsule().stroke(
                Color("Colors/Opacity/Black/regular/30"),
                lineWidth: 1
            )
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        ColorPill(color: Color(hex: "D94544"), label: "accent")
        ColorPill(color: .white,                label: "accent text color")
        ColorPill(color: Color(hex: "FFFCF0"),  label: "background")
        ColorPill(color: .black,                label: "text color")
    }
    .padding(24)
    .background(Color.Background.elevated)
}
