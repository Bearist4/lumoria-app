//
//  MemoryLimitHero.swift
//  Lumoria App
//
//  Three filled "memory" cards stacked left-to-right with a ghosted
//  fourth card behind them — visualising the free-tier ceiling.
//

import SwiftUI

struct MemoryLimitHero: View {

    private let accent = PaywallTrigger.Variant.memoryLimit.accent

    var body: some View {
        ZStack {
            // Ghost "4th" card — the locked one.
            card(emoji: "🔒", filled: false)
                .offset(x: 80, y: 12)
                .opacity(0.5)

            // 3 filled memory cards (the free-tier limit).
            card(emoji: "🎟️", filled: true)
                .offset(x: -56, y: -12)
                .rotationEffect(.degrees(-6))

            card(emoji: "✈️", filled: true)
                .offset(x: 0, y: 0)

            card(emoji: "🎵", filled: true)
                .offset(x: 56, y: -8)
                .rotationEffect(.degrees(6))
        }
    }

    private func card(emoji: String, filled: Bool) -> some View {
        let bg: AnyShapeStyle = filled
            ? AnyShapeStyle(LinearGradient(
                colors: [accent.opacity(0.95), accent.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ))
            : AnyShapeStyle(Color.gray.opacity(0.15))
        return RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(bg)
            .frame(width: 92, height: 124)
            .overlay(
                Text(emoji)
                    .font(.system(size: 36))
                    .opacity(filled ? 1 : 0.6)
            )
            .shadow(color: filled ? accent.opacity(0.35) : .clear,
                    radius: 12, y: 6)
    }
}

#Preview {
    MemoryLimitHero().frame(height: 200).padding(24)
}
