//
//  AuthChooserStepView.swift
//  Lumoria App
//
//  First step inside the floating auth bottom sheet — title + intro
//  copy + the three vertically-stacked CTAs.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2000-140379
//

import SwiftUI

struct AuthChooserStepView: View {
    let onContinueWithEmail: () -> Void
    let onApple: () -> Void
    let onGoogle: () -> Void
    let onDismiss: () -> Void
    let isSocialLoading: Bool
    let socialError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text("Welcome to Lumoria")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.Text.primary)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.Text.primary)
                            .frame(width: 32, height: 32)
                            .background(Color.Background.fieldFill)
                            .clipShape(Circle())
                    }
                }
                Text("Sign in to save your tickets and turn them into memories.")
                    .font(.body)
                    .foregroundStyle(Color.Text.secondary)
            }

            VStack(spacing: 8) {
                Button("Continue with Email", action: onContinueWithEmail)
                    .lumoriaButtonStyle(.primary)

                if let socialError {
                    Text(socialError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                appleButton
                googleButton
            }
        }
        .padding(24)
    }

    private var appleButton: some View {
        Button(action: onApple) {
            HStack(spacing: 5) {
                if isSocialLoading {
                    ProgressView()
                } else {
                    Image(systemName: "applelogo")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("Continue with Apple")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "BFBFBF"), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isSocialLoading)
        .accessibilityLabel("Continue with Apple")
    }

    private var googleButton: some View {
        Button(action: onGoogle) {
            HStack(spacing: 10) {
                if isSocialLoading {
                    ProgressView()
                } else {
                    Image("google-g")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17, height: 18)
                    Text("Continue with Google")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.Text.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(hex: "FAFAFA"))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "BFBFBF"), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isSocialLoading)
        .accessibilityLabel("Continue with Google")
    }
}
