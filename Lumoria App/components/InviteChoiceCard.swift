//
//  InviteChoiceCard.swift
//  Lumoria App
//
//  Selectable card used by the two invite-reward sheets (referrer +
//  referree) to pick between a +1 memory bonus and a +2 ticket bonus.
//  188 × 209 pt frame: illustration up top, label below; selected
//  state adds a 3pt black-30 border and bumps the label to semibold.
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2186-177709
//

import SwiftUI

struct InviteChoiceCard<Illustration: View>: View {
    let label: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let illustration: () -> Illustration

    var body: some View {
        Button(action: action) {
            VStack(spacing: 20) {
                illustration()
                    .frame(maxWidth: .infinity, maxHeight: 130, alignment: .center)

                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(Color.Text.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .frame(height: 209)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color("Colors/Opacity/Black/inverse/3"))
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            Color("Colors/Opacity/Black/regular/30"),
                            lineWidth: 3
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#if DEBUG
#Preview("Pair") {
    HStack(spacing: 16) {
        InviteChoiceCard(
            label: "1 additional memory",
            isSelected: true,
            action: {}
        ) {
            RoundedRectangle(cornerRadius: 10).fill(Color("Colors/Opacity/Black/inverse/3"))
        }
        InviteChoiceCard(
            label: "2 additional ticket slots",
            isSelected: false,
            action: {}
        ) {
            RoundedRectangle(cornerRadius: 10).fill(Color("Colors/Opacity/Black/inverse/3"))
        }
    }
    .padding(24)
    .background(Color.Background.default)
}
#endif
