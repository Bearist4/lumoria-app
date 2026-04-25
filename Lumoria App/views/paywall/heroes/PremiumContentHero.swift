//
//  PremiumContentHero.swift
//  Lumoria App
//
//  3×2 grid of small ticket-template thumbnails — first two unlocked,
//  remaining four locked. Visualises the "full catalogue" message:
//  free users get a couple of templates, paying users get every one.
//

import SwiftUI

struct PremiumContentHero: View {

    private let accent = PaywallTrigger.Variant.premiumContent.accent

    private let tiles: [(symbol: String, locked: Bool, tint: Color)] = [
        ("airplane.circle.fill",      false, .blue),
        ("tram.circle.fill",          false, .red),
        ("music.note.list",           true,  .pink),
        ("ticket.fill",               true,  .purple),
        ("fork.knife.circle.fill",    true,  .orange),
        ("film.fill",                 true,  .indigo),
    ]

    var body: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]

        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(tiles.indices, id: \.self) { i in
                tile(tiles[i])
            }
        }
        .frame(maxWidth: 280)
    }

    private func tile(_ t: (symbol: String, locked: Bool, tint: Color)) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(t.tint.opacity(t.locked ? 0.12 : 0.18))
                .aspectRatio(1, contentMode: .fit)

            Image(systemName: t.symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(t.tint.opacity(t.locked ? 0.5 : 1))

            if t.locked {
                ZStack {
                    Circle().fill(.white)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accent)
                }
                .frame(width: 22, height: 22)
                .offset(x: 22, y: -22)
                .shadow(radius: 2, y: 1)
            }
        }
    }
}

#Preview {
    PremiumContentHero().frame(height: 200).padding(24)
}
