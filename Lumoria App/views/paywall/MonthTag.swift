//
//  MonthTag.swift
//  Lumoria App
//
//  Small chip that sits inside a PlanCard tile.
//  Figma: 968-17993
//

import SwiftUI

struct MonthTag: View {
    enum Kind: Equatable {
        case trial(_ text: String)        // e.g. "14 days free"
        case bestValue(_ text: String)    // e.g. "Best value"
        case oneTime(_ text: String)      // e.g. "One-time"
    }

    let kind: Kind

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
    }

    private var text: String {
        switch kind {
        case .trial(let t), .bestValue(let t), .oneTime(let t): return t
        }
    }

    private var foreground: Color {
        switch kind {
        case .trial:     return Color.white
        case .bestValue: return Color.white
        case .oneTime:   return Color.Text.primary
        }
    }

    private var background: Color {
        switch kind {
        case .trial:     return Color.accentColor
        case .bestValue: return Color.green
        case .oneTime:   return Color.gray.opacity(0.2)
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        MonthTag(kind: .trial("14 days free"))
        MonthTag(kind: .bestValue("Best value"))
        MonthTag(kind: .oneTime("One-time"))
    }
}
