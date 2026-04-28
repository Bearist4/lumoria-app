//
//  AuthFlowSheet.swift
//  Lumoria App
//
//  Two presentations driven by AuthFlowCoordinator:
//
//  1. AuthChooserSheetContent — small floating bottom sheet that appears
//     first (Continue with email + Apple + Google).
//  2. AuthFlowModalContent — full-height system sheet hosting the email
//     entry, login, or signup step. The morph (email → login or signup)
//     happens inside this modal as a content swap; the modal stays
//     presented across all three states.
//
//  LandingView attaches both via separate bindings derived from the
//  coordinator's step. Tapping Continue with email transitions step from
//  .chooser to .email, which dismisses the floating sheet and presents
//  the modal — handled by SwiftUI as the bindings flip.
//

import SwiftUI

// MARK: - Floating bottom sheet content (chooser only)

struct AuthChooserSheetContent: View {
    @ObservedObject var coordinator: AuthFlowCoordinator
    @EnvironmentObject private var auth: AuthManager

    @State private var isSocialLoading = false
    @State private var socialError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    Analytics.track(.authFlowDismissed(atStep: .chooser))
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

            AuthChooserStepView(
                onContinueWithEmail: coordinator.continueWithEmail,
                onApple: signInWithApple,
                onGoogle: signInWithGoogle,
                isSocialLoading: isSocialLoading,
                socialError: socialError
            )
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

// MARK: - Full-height system modal (email/login/signup with morph)

struct AuthFlowModalContent: View {
    @ObservedObject var coordinator: AuthFlowCoordinator

    var body: some View {
        ZStack(alignment: .top) {
            Color.Background.default.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                stepBody
                    .animation(.spring(duration: 0.35), value: coordinator.step)
                Spacer(minLength: 0)
            }
        }
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(38)
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            if coordinator.step != .email {
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
        .padding(.top, 10)
    }

    @ViewBuilder
    private var stepBody: some View {
        switch coordinator.step {
        case .chooser:
            // Should not appear here — chooser is a separate presentation.
            EmptyView()

        case .email:
            EmailEntryStepView(
                email: $coordinator.email,
                isLoading: coordinator.isCheckingEmail,
                errorMessage: coordinator.errorMessage,
                onContinue: handleEmailSubmit
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .leading)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))

        case .login(let email):
            InSheetLoginView(email: email, onSuccess: coordinator.dismiss)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .trailing))
                ))

        case .signup(let email):
            InSheetSignupView(email: email, onSuccess: coordinator.dismiss)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .trailing))
                ))
        }
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
                    let rateLimitMsg = String(localized: "Too many tries — try again in a moment")
                    return coordinator.errorMessage == rateLimitMsg ? .rate_limited : .error
                case .chooser: return .error
                }
            }()
            Analytics.track(.authFlowEmailSubmitted(emailDomain: domain, outcome: outcome))
        }
    }
}
