//
//  LumoriaPremiumBadge.swift
//  Lumoria App
//
//  Premium indicator from figma 1994:130463. Two variants:
//    - .crown: 24pt purple disc with a heart glyph (form steps,
//      settings status row, invite landing toolbar). Name is a
//      legacy holdover from the original crown art — the rendered
//      icon is `heart.fill` so the marker reads as "from us, with
//      love" instead of monarchical-tier premium.
//    - .valueOffer(text): purple pill with white text, used for
//      marketing copy such as "2 months free".
//

import SwiftUI

struct LumoriaPremiumBadge: View {
    enum Style: Equatable {
        case crown
        case valueOffer(String)
    }

    let style: Style

    var body: some View {
        switch style {
        case .crown:
            ZStack {
                Circle()
                    .fill(Color("Colors/Purple/400"))
                    .frame(width: 24, height: 24)
                Image(systemName: "heart.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(Text("Premium"))

        case .valueOffer(let text):
            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color("Colors/Purple/400"))
                )
        }
    }
}

#if DEBUG
#Preview("Crown") {
    LumoriaPremiumBadge(style: .crown)
        .padding()
        .background(Color.Background.default)
}

#Preview("Value offer") {
    LumoriaPremiumBadge(style: .valueOffer("2 months free"))
        .padding()
        .background(Color.Background.default)
}
#endif
