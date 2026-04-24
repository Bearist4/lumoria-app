//
//  WelcomeSheetView.swift
//  Lumoria App
//
//  First-run tutorial welcome. Bottom-sheet style with an inset hero
//  panel + headline + body + Start / X actions. See Figma node
//  1902-103368.
//

import SwiftUI

struct WelcomeSheetView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            hero

            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome to Lumoria!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.Text.primary)

                Text("Memories gather tickets into one place — a trip, a season, a night out. Whatever you want to hold onto.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Start tutorial") {
                Task { await coordinator.startTutorial() }
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
                Task { await coordinator.dismissWelcomeSilently() }
            }
            .padding(12)
            .accessibilityLabel(Text("Close"))
        }
    }
}
