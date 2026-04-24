//
//  OnboardingTipCard.swift
//  Lumoria App
//
//  Blue tip card with title, body, and an X button. Visuals match the
//  Figma tip component (see 2026-04-24-onboarding-rework-design.md).
//  The X triggers the leave-tutorial alert on the coordinator.
//

import SwiftUI

struct OnboardingTipCopy: Equatable {
    let title: LocalizedStringKey
    let body: LocalizedStringKey
    /// Optional emoji rendered next to the title.
    let leadingEmoji: String?

    init(title: LocalizedStringKey,
         body: LocalizedStringKey,
         leadingEmoji: String? = nil) {
        self.title = title
        self.body = body
        self.leadingEmoji = leadingEmoji
    }
}

struct OnboardingTipCard: View {
    let copy: OnboardingTipCopy
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let emoji = copy.leadingEmoji {
                    Text(emoji).font(.system(size: 20))
                }
                Text(copy.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                LumoriaIconButton(
                    systemImage: "xmark",
                    size: .small,
                    position: .onDark,
                    action: onClose
                )
                .accessibilityLabel(Text("Leave the tutorial"))
            }
            Text(copy.body)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 300, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.294, green: 0.349, blue: 0.933))
        )
        .shadow(color: .black.opacity(0.15), radius: 14, y: 6)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        OnboardingTipCard(
            copy: OnboardingTipCopy(
                title: "Create a memory",
                body: "Memories gather tickets into one place. Create one by tapping the + button."
            ),
            onClose: {}
        )
        .padding()
    }
}
