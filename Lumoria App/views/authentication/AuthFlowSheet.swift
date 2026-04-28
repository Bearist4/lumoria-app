//
//  AuthFlowSheet.swift
//  Lumoria App
//
//  Root content of the floating bottom sheet that morphs through
//  chooser → email → login or signup. Animation lives here so each
//  step subview stays presentational.
//

import SwiftUI

struct AuthFlowSheet: View {
    @ObservedObject var coordinator: AuthFlowCoordinator
    @EnvironmentObject private var auth: AuthManager

    @State private var isSocialLoading = false
    @State private var socialError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            stepBody
                .animation(.spring(duration: 0.35), value: coordinator.step)
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            if showsBack {
                Button {
                    Analytics.track(.authFlowBackPressed(fromStep: stepProp))
                    coordinator.back()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color.Text.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.Background.fieldFill)
                        .clipShape(Circle())
                }
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            Button {
                Analytics.track(.authFlowDismissed(atStep: stepProp))
                coordinator.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.Background.fieldFill)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var stepBody: some View {
        switch coordinator.step {
        case .chooser:
            AuthChooserStepView(
                onContinueWithEmail: coordinator.continueWithEmail,
                onApple: signInWithApple,
                onGoogle: signInWithGoogle,
                isSocialLoading: isSocialLoading,
                socialError: socialError
            )
            .transition(.opacity.combined(with: .move(edge: .leading)))

        case .email:
            EmailEntryStepView(
                email: $coordinator.email,
                isLoading: coordinator.isCheckingEmail,
                errorMessage: coordinator.errorMessage,
                onContinue: handleEmailSubmit
            )
            .transition(.opacity.combined(with: .move(edge: .trailing)))

        case .login(let email):
            InSheetLoginView(email: email, onSuccess: coordinator.dismiss)
                .transition(.opacity.combined(with: .move(edge: .trailing)))

        case .signup(let email):
            InSheetSignupView(email: email, onSuccess: coordinator.dismiss)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    private var showsBack: Bool {
        coordinator.step != .chooser
    }

    private var stepProp: AuthFlowStepProp {
        switch coordinator.step {
        case .chooser: return .chooser
        case .email: return .email
        case .login: return .login
        case .signup: return .signup
        }
    }

    private func handleEmailSubmit() {
        let domain = AnalyticsIdentity.emailDomain(coordinator.email) ?? "unknown"
        Task {
            await coordinator.submitEmail()
            let outcome: AuthFlowEmailOutcomeProp = {
                switch coordinator.step {
                case .login: return .exists
                case .signup: return .does_not_exist
                case .email:
                    // Still on email step → either rate-limited or transport error.
                    // Distinguish via the surfaced error message; the coordinator
                    // sets the rate-limit string verbatim.
                    let rateLimitMsg = String(localized: "Too many tries — try again in a moment")
                    return coordinator.errorMessage == rateLimitMsg ? .rate_limited : .error
                case .chooser: return .error
                }
            }()
            Analytics.track(.authFlowEmailSubmitted(emailDomain: domain, outcome: outcome))
        }
    }

    private func signInWithApple() {
        socialError = nil
        isSocialLoading = true
        Task {
            defer { isSocialLoading = false }
            do { try await auth.signInWithApple() }
            catch AppleSignInService.AppleSignInError.canceled { /* silent */ }
            catch { socialError = error.localizedDescription }
        }
    }

    private func signInWithGoogle() {
        socialError = nil
        isSocialLoading = true
        Task {
            defer { isSocialLoading = false }
            do { try await auth.signInWithGoogle() }
            catch GoogleSignInService.GoogleSignInError.canceled { /* silent */ }
            catch { socialError = error.localizedDescription }
        }
    }
}
