//
//  LumoriaRadio.swift
//  Lumoria App
//
//  Single-source radio indicator. 24×24 visual on a 44×44 tap zone.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2028-143084
//

import SwiftUI

struct LumoriaRadio: View {

    let isSelected: Bool

    /// Visual circle diameter from Figma.
    private let diameter: CGFloat = 24
    /// Inner-dot diameter for the selected state. Kept proportional to
    /// `diameter` so the radio scales cleanly if a future variant needs
    /// a larger size.
    private var innerDiameter: CGFloat { diameter * 0.5 }
    /// Tap-target size — Apple's HIG minimum.
    private let hitArea: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.Text.primary, lineWidth: 2)
                .frame(width: diameter, height: diameter)

            // Always render the inner dot — opacity controls
            // selected/unselected. A conditional `if` would let
            // SwiftUI insert the dot via its default transition,
            // which (when the surrounding row is mid-animation)
            // would render the dot at its final position while the
            // ring is still moving — visible as a "pop" out of
            // place.
            Circle()
                .fill(Color.Text.primary)
                .frame(width: innerDiameter, height: innerDiameter)
                .opacity(isSelected ? 1 : 0)
        }
        .frame(width: hitArea, height: hitArea)
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    HStack(spacing: 32) {
        LumoriaRadio(isSelected: true)
        LumoriaRadio(isSelected: false)
    }
    .padding()
    .background(Color.Background.default)
}
