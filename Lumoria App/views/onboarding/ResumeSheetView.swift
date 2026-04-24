//
//  ResumeSheetView.swift
//  Lumoria App
//
//  Presented on cold launch when show_onboarding=true and
//  onboarding_step != welcome. Offers: continue the tutorial, or leave it.
//

import SwiftUI

struct ResumeSheetView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Image("onboarding/cover")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .clipped()
                    .accessibilityHidden(true)

                Button {
                    Task { await coordinator.declineResume() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.9), in: Circle())
                }
                .padding(16)
                .accessibilityLabel(Text("Leave the tutorial"))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome back")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.Text.primary)

                Text("Want to continue where you left off in the tutorial?")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            Button {
                Task { await coordinator.resume() }
            } label: {
                Text("Continue tutorial")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.Text.primary)
                    .foregroundStyle(Color.Background.default)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.Background.default)
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }
}
