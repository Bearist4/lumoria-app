//
//  OnboardingEndSheetView.swift
//  Lumoria App
//
//  Presented on the Memories tab after the user finishes the tutorial.
//  See Figma node 1905-113490.
//

import SwiftUI

struct OnboardingEndSheetView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            hero

            VStack(alignment: .leading, spacing: 12) {
                Text("All done!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.Text.primary)

                Text("You can now enjoy Lumoria and create beautiful tickets for every moments you'd like to remember. We just covered the basics of Lumoria. There's so many more features waiting to be discovered.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Start using Lumoria") {
                Task { await coordinator.finishAtEndCover() }
            }
            .lumoriaButtonStyle(.primary, size: .large)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            Image("onboarding/end_cover")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)

            LumoriaIconButton(
                systemImage: "xmark",
                size: .medium,
                position: .onBackground
            ) {
                Task { await coordinator.finishAtEndCover() }
            }
            .padding(12)
            .accessibilityLabel(Text("Close"))
        }
    }
}
