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
        case .information: return Color.Feedback.Information.surface
        case .warning:     return Color.Feedback.Warning.surface
        case .success:     return Color.Feedback.Success.surface
        case .danger:      return Color.Feedback.Danger.surface
        case .neutral:     return Color.Feedback.Neutral.surface
        }
    }

    var foreground: Color {
        switch self {
        case .information: return Color.Feedback.Information.text
        case .warning:     return Color.Feedback.Warning.text
        case .success:     return Color.Feedback.Success.text
        case .danger:      return Color.Feedback.Danger.text
        case .neutral:     return Color.Feedback.Neutral.text
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
                .font(.callout.weight(.semibold))
                .lineSpacing(21 - 16)

            if let description {
                Text(description)
                    .font(.callout)
                    .lineSpacing(21 - 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let subtext {
                Text(subtext)
                    .font(.footnote.italic())
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
