//
//  TicketLimitHero.swift
//  Lumoria App
//
//  Five fanned ticket-shaped tiles representing the free-tier ticket
//  cap, with a sixth ghosted ticket behind them as the "more"
//  affordance.
//

import SwiftUI

struct TicketLimitHero: View {

    private let accent = PaywallTrigger.Variant.ticketLimit.accent

    var body: some View {
        ZStack {
            // Ghost "6th" ticket peeking out behind.
            ticket(filled: false)
                .rotationEffect(.degrees(8))
                .offset(x: 0, y: 16)
                .opacity(0.4)

            // The 5 free tickets, fanned.
            ForEach(0..<5, id: \.self) { i in
                let angle = Double(i - 2) * 6.0
                let xOffset = CGFloat(i - 2) * 12
                ticket(filled: true)
                    .rotationEffect(.degrees(angle))
                    .offset(x: xOffset, y: 0)
            }
        }
    }

    private func ticket(filled: Bool) -> some View {
        let bg: AnyShapeStyle = filled
            ? AnyShapeStyle(LinearGradient(
                colors: [accent.opacity(0.95), accent.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
              ))
            : AnyShapeStyle(Color.gray.opacity(0.15))
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(bg)
            .frame(width: 80, height: 130)
            .overlay(
                VStack(spacing: 8) {
                    Capsule()
                        .fill(Color.white.opacity(filled ? 0.6 : 0.3))
                        .frame(width: 32, height: 4)
                    Capsule()
                        .fill(Color.white.opacity(filled ? 0.4 : 0.2))
                        .frame(width: 48, height: 4)
                    Spacer()
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(filled ? 0.85 : 0.4))
                        .padding(.bottom, 12)
                }
                .padding(.top, 18)
            )
            .shadow(color: filled ? accent.opacity(0.3) : .clear,
                    radius: 8, y: 4)
    }
}

#Preview {
    TicketLimitHero().frame(height: 200).padding(24)
}
