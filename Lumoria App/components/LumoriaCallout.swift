//
//  LumoriaCallout.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=720-9566
//

import SwiftUI

// MARK: - Type

enum CalloutType {
    case information
    case warning
    case success
    case danger
    case neutral

    var background: Color {
        switch self {
        case .information: return Color("Colors/Blue/50")
        case .warning:     return Color("Colors/Yellow/50")
        case .success:     return Color("Colors/Green/50")
        case .danger:      return Color("Colors/Red/50")
        case .neutral:     return Color("Colors/Gray/50")
        }
    }

    var foreground: Color {
        switch self {
        case .information: return Color("Colors/Blue/700")
        case .warning:     return Color("Colors/Yellow/700")
        case .success:     return Color("Colors/Green/700")
        case .danger:      return Color("Colors/Red/700")
        case .neutral:     return Color("Colors/Gray/700")
        }
    }
}

// MARK: - Callout

struct LumoriaCallout: View {
    let title: String
    var description: String? = nil
    var subtext: String? = nil
    var type: CalloutType = .information

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .tracking(-0.31)
                .lineSpacing(21 - 16)

            if let description {
                Text(description)
                    .font(.system(size: 16, weight: .regular))
                    .tracking(-0.31)
                    .lineSpacing(21 - 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let subtext {
                Text(subtext)
                    .font(.system(size: 13, weight: .regular).italic())
                    .tracking(-0.08)
                    .lineSpacing(18 - 13)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(type.foreground)
        .padding(Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(type.background)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.s4, style: .continuous))
    }
}

// MARK: - Preview

#Preview("Callouts") {
    VStack(spacing: Spacing.s4) {
        LumoriaCallout(
            title: "Title",
            description: "Description",
            subtext: "Subtext",
            type: .information
        )
        LumoriaCallout(
            title: "Title",
            description: "Description",
            subtext: "Subtext",
            type: .warning
        )
        LumoriaCallout(
            title: "Title",
            description: "Description",
            subtext: "Subtext",
            type: .success
        )
        LumoriaCallout(
            title: "Title",
            description: "Description",
            subtext: "Subtext",
            type: .danger
        )
        LumoriaCallout(
            title: "Title",
            description: "Description",
            subtext: "Subtext",
            type: .neutral
        )
    }
    .padding(Spacing.s4)
    .frame(maxWidth: 408)
    .background(Color.Background.default)
}
