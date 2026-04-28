//
//  AuthChooserStepView.swift
//  Lumoria App
//
//  First step inside the floating auth sheet — Continue with email +
//  Apple icon + Google icon.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-8016
//

import SwiftUI

struct AuthChooserStepView: View {
    let onContinueWithEmail: () -> Void
    let onApple: () -> Void
    let onGoogle: () -> Void
    let isSocialLoading: Bool
    let socialError: String?

    var body: some View {
        VStack(spacing: 16) {
            Button("Continue with email", action: onContinueWithEmail)
                .lumoriaButtonStyle(.primary)

            Text("or")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.Text.primary)

            if let socialError {
                Text(socialError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 24) {
                Button(action: onGoogle) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                        if isSocialLoading {
                            ProgressView()
                        } else {
                            Image("google-g")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .disabled(isSocialLoading)
                .accessibilityLabel("Continue with Google")

                Button(action: onApple) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black)
                        if isSocialLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "applelogo")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .disabled(isSocialLoading)
                .accessibilityLabel("Continue with Apple")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }
}
