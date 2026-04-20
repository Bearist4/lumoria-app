//
//  WelcomeSheetView.swift
//  Lumoria App
//
//  One-shot onboarding welcome sheet shown after signup. Calls
//  OnboardingCoordinator.start() or .skip() when the user picks.
//

import SwiftUI

struct WelcomeSheetView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @Environment(\.brandSlug) private var brandSlug

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)

            hero
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)

            Text("Create your first ticket in three steps.")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 24)

            Text("About a minute.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.Text.secondary)
                .padding(.top, 8)
                .padding(.horizontal, 24)

            steps
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Spacer()

            ctaStack
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .background(Color.Background.default.ignoresSafeArea())
        .interactiveDismissDisabled(true)
    }

    // MARK: - Hero

    private var hero: some View {
        Image("brand/\(brandSlug)/logomark")
            .resizable()
            .scaledToFit()
            .frame(width: 96, height: 96)
    }

    // MARK: - Steps

    private var steps: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepRow(index: 1, label: "Create a memory")
            stepRow(index: 2, label: "Add a ticket")
            stepRow(index: 3, label: "Share it")
        }
    }

    private func stepRow(index: Int, label: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.Text.primary)
                    .frame(width: 24, height: 24)
                Text("\(index)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.Background.default)
            }
            Text(label)
                .font(.system(size: 17))
                .foregroundStyle(Color.Text.primary)
        }
    }

    // MARK: - CTAs

    private var ctaStack: some View {
        VStack(spacing: 8) {
            Button {
                coordinator.start()
            } label: {
                Text("Start")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.Text.primary)
                    .foregroundStyle(Color.Background.default)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button {
                coordinator.skip()
            } label: {
                Text("Skip")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.Text.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }
}
