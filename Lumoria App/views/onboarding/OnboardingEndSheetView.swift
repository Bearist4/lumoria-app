//
//  OnboardingEndSheetView.swift
//  Lumoria App
//
//  Presented on the Memories tab after the user finishes the tutorial.
//  Celebratory wrap-up. See Figma node 1905-113490.
//

import SwiftUI

struct OnboardingEndSheetView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Image("onboarding/end_cover")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .accessibilityHidden(true)

                Button {
                    Task { await coordinator.finishAtEndCover() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.9), in: Circle())
                }
                .padding(16)
                .accessibilityLabel(Text("Close"))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("All done!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.Text.primary)

                Text("You can now enjoy Lumoria and create beautiful tickets for every moments you'd like to remember. We just covered the basics of Lumoria. There's so many more features waiting to be discovered.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            Button {
                Task { await coordinator.finishAtEndCover() }
            } label: {
                Text("Start using Lumoria")
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
        .presentationDetents([.height(480)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }
}
