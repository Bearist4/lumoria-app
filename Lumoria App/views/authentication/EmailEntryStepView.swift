//
//  EmailEntryStepView.swift
//  Lumoria App
//
//  Email-only step inside the floating auth sheet. On Continue we hand
//  back to the coordinator to call checkEmailExists and morph into login
//  or signup.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=2000-140461
//

import SwiftUI

struct EmailEntryStepView: View {
    @Binding var email: String
    let isLoading: Bool
    let errorMessage: String?
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome to Lumoria")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.Text.primary)
                Text("Log in to Lumoria")
                    .font(.body)
                    .foregroundStyle(Color.Text.primary)
            }

            VStack(alignment: .leading, spacing: 20) {
                LumoriaInputField(
                    label: "Email address",
                    placeholder: "Your email address",
                    text: $email,
                    contentType: .emailAddress,
                    keyboardType: .emailAddress,
                    inputIdentifier: "auth_email_field"
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.Feedback.Danger.text)
                }
            }

            Button(action: onContinue) {
                if isLoading {
                    ProgressView().tint(Color.Text.OnColor.white)
                } else {
                    Text("Continue")
                }
            }
            .lumoriaButtonStyle(.primary)
            .disabled(email.isEmpty || isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }
}
