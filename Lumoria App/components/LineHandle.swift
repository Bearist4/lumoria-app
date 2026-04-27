//
//  LineHandle.swift
//  Lumoria App
//
//  Pill marker for one operator line. Coloured background from
//  `TransitLine.color`, white mode glyph on the leading edge and
//  the line short-name in heavy rounded type. Used in the route
//  dropdown's collapsed / expanded states and anywhere a chain of
//  lines needs to be shown compactly.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1876-49431
//

import SwiftUI

struct LineHandle: View {
    let line: TransitLine
    var size: Size = .medium

    enum Size {
        /// Used in the collapsed dropdown field and route-row chain.
        case medium
        /// Slightly tighter variant for dense layouts.
        case small
    }

    var body: some View {
        HStack(spacing: iconTextGap) {
            Image(systemName: line.resolvedMode.symbol)
                .font(iconFont)
                .foregroundStyle(.white)
            Text(line.displayLabel)
                .font(labelFont)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            Capsule().fill(Color(hex: line.color))
        )
    }

    // MARK: - Metrics

    private var iconFont: Font {
        switch size {
        case .small:  return .system(size: 9,  weight: .semibold)
        case .medium: return .system(size: 11, weight: .semibold)
        }
    }

    private var labelFont: Font {
        switch size {
        case .small:  return .system(size: 10, weight: .heavy, design: .rounded)
        case .medium: return .system(size: 12, weight: .heavy, design: .rounded)
        }
    }

    private var iconTextGap: CGFloat { size == .small ? 3 : 4 }
    private var horizontalPadding: CGFloat { size == .small ? 8 : 10 }
    private var verticalPadding: CGFloat { size == .small ? 3 : 4 }
}
