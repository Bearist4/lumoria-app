//
//  LumoriaGroupBadge.swift
//  Lumoria App
//
//  Count pill rendered on top of a ticket card when the ticket is the
//  representative of a multi-leg group (e.g. an underground journey
//  that spans several lines). Mirrors the standalone "_groupBadge"
//  spec in Figma.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2116-98332
//

import SwiftUI

struct LumoriaGroupBadge: View {

    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.Background.default)
            .frame(width: 48, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.Text.primary)
            )
    }
}

#Preview {
    HStack(spacing: 12) {
        LumoriaGroupBadge(count: 2)
        LumoriaGroupBadge(count: 3)
        LumoriaGroupBadge(count: 12)
    }
    .padding(24)
    .background(Color.Background.default)
}
