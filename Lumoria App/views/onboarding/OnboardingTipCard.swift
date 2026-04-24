//
//  OnboardingTipCard.swift
//  Lumoria App
//
//  Blue tip card shown over each overlay step. Exact tokens from the
//  Figma design (node 1903:103587):
//    - bg: indigo/600 (#435bd2)
//    - padding: 16pt
//    - corner radius: 24pt
//    - title → description gap: 12pt
//    - close button: 32pt circle, top-right with 8pt inset
//    - title: SF Pro Semibold 17 / 22 / -0.43
//    - description: SF Pro Regular 15 / 20 / -0.23
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let emoji = copy.leadingEmoji {
                    Text(emoji)
                        .font(.system(size: 17))
                }
                Text(copy.title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.43)
                    .lineSpacing(22 - 17) // line-height 22 on 17pt font
                    .foregroundStyle(Color.Text.OnColor.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Reserve room for the absolutely-positioned close button on
            // the first line so the title never overlaps the X.
            .padding(.trailing, 32)

            Text(copy.body)
                .font(.system(size: 15, weight: .regular))
                .tracking(-0.23)
                .lineSpacing(20 - 15)
                .foregroundStyle(Color.Text.OnColor.white)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(width: 302, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 67/255, green: 91/255, blue: 210/255))
        )
        .overlay(alignment: .topTrailing) {
            LumoriaIconButton(
                systemImage: "xmark",
                size: .small,
                position: .onDark,
                action: onClose
            )
            .padding(8)
            .accessibilityLabel(Text("Leave the tutorial"))
        }
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
