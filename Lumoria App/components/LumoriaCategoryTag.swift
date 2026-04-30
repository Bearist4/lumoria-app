//
//  LumoriaCategoryTag.swift
//  Lumoria App
//
//  Rounded category pill used inside `TicketEntryRow` and anywhere a
//  ticket needs a quick visual category badge.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2027-142068
//

import SwiftUI

struct LumoriaCategoryTag: View {

    let category: TicketCategoryStyle

    var body: some View {
        Text(category.pillLabel)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(category.onColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(category.backgroundColor)
            )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        LumoriaCategoryTag(category: .plane)
        LumoriaCategoryTag(category: .train)
        LumoriaCategoryTag(category: .publicTransit)
        LumoriaCategoryTag(category: .concert)
    }
    .padding()
    .background(Color.Background.default)
}
