//
//  ResumeSheetView.swift
//  Lumoria App
//
//  Presented on cold launch when show_onboarding=true and
//  onboarding_step != welcome. Inherits the Welcome sheet shell.
//

import SwiftUI

struct ResumeSheetView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            hero

            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome back")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.Text.primary)

                Text("Want to continue where you left off in the tutorial?")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Continue tutorial") {
                Task { await coordinator.resume() }
            }
            .lumoriaButtonStyle(.primary, size: .large)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            Image("onboarding/cover")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)

            LumoriaIconButton(
                systemImage: "xmark",
                size: .medium,
                position: .onBackground
            ) {
                Task { await coordinator.declineResume() }
            }
            .padding(12)
            .accessibilityLabel(Text("Leave the tutorial"))
        }
    }
}
