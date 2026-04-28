//
//  LandingView.swift
//  Lumoria App
//
//  Landing screen shown to unauthenticated users.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-8016
//

import SwiftUI

struct LandingView: View {
    @Environment(\.brandSlug) private var brandSlug
    @EnvironmentObject private var auth: AuthManager

    @State private var showLogIn = false
    @State private var showSignUp = false
    @State private var isSocialLoading = false
    @State private var socialError: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.Background.default.ignoresSafeArea()

            // Scrollable center content
            VStack(spacing: 0) {
                Spacer()

                logogramView

                Spacer().frame(height: 54)

                logotypeView
                    .frame(width: 226, height: 90)
                    .opacity(0.3)

                headlineView

                Spacer().frame(height: 32)

                Text("By signing up you agree to our Terms and Privacy Policy.")
                    .font(.footnote)
                    .foregroundStyle(Color.Text.secondary)
                    .tint(Color.Text.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Reserve height for pinned buttons + safe area
                Spacer().frame(height: 296)
            }

            // Pinned bottom CTAs
            VStack(spacing: 16) {
                Button("Log in") { showLogIn = true }
                    .lumoriaButtonStyle(.secondary)
                Button("Sign up") { showSignUp = true }
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
                    googleIconButton
                    appleIconButton
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showLogIn) {
            LogInView(onCreateAccount: {
                showLogIn = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showSignUp = true
                }
            })
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView(onLogIn: {
                showSignUp = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showLogIn = true
                }
            })
        }
    }

    // MARK: - Logogram

    private var logogramView: some View {
        Image("brand/\(brandSlug)/logomark")
            .resizable()
            .scaledToFit()
            .frame(width: 137, height: 137)
    }

    // MARK: - Logotype

    private var logotypeView: some View {
        Image("brand/\(brandSlug)/logo")
            .resizable()
            .scaledToFit()
    }

    // MARK: - Social icon buttons

    private var googleIconButton: some View {
        Button(action: signInWithGoogle) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                if isSocialLoading {
                    ProgressView()
                } else {
                    googleGlyph
                        .frame(width: 18, height: 18)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .disabled(isSocialLoading)
        .accessibilityLabel("Continue with Google")
    }

    private var appleIconButton: some View {
        Button(action: signInWithApple) {
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
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .disabled(isSocialLoading)
        .accessibilityLabel("Continue with Apple")
    }

    /// Multi-color "G" — flat SVG-equivalent rendered with a stack of
    /// stroke arcs. Approximates Google's official mark for an icon-only
    /// button at 18pt. If you want pixel-perfect, drop in the official
    /// asset and swap.
    private var googleGlyph: some View {
        Text("G")
            .font(.system(size: 22, weight: .heavy, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.92, green: 0.26, blue: 0.21), location: 0),     // red
                        .init(color: Color(red: 0.98, green: 0.74, blue: 0.02), location: 0.33),  // yellow
                        .init(color: Color(red: 0.20, green: 0.66, blue: 0.33), location: 0.66),  // green
                        .init(color: Color(red: 0.26, green: 0.52, blue: 0.96), location: 1),     // blue
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func signInWithApple() {
        socialError = nil
        isSocialLoading = true
        Task {
            defer { isSocialLoading = false }
            do {
                try await auth.signInWithApple()
            } catch AppleSignInService.AppleSignInError.canceled {
                // silent
            } catch {
                socialError = error.localizedDescription
            }
        }
    }

    private func signInWithGoogle() {
        socialError = nil
        isSocialLoading = true
        Task {
            defer { isSocialLoading = false }
            do {
                try await auth.signInWithGoogle()
            } catch GoogleSignInService.GoogleSignInError.canceled {
                // silent
            } catch {
                socialError = error.localizedDescription
            }
        }
    }

    // MARK: - Headline

    private var headlineView: some View {
        // "Tickets that last" in primary text (adapts to dark mode) +
        // "forever" with brand rainbow gradient.
        // Gradient L→R: blue #57B7F5 · orange #FFA96C · yellow #FDDC51 · pink #FF9CCC
        (Text("Tickets that last ")
            .foregroundStyle(Color.Text.primary)
        + Text("forever")
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "57B7F5"), location: 0),
                        .init(color: Color(hex: "FFA96C"), location: 0.338),
                        .init(color: Color(hex: "FDDC51"), location: 0.659),
                        .init(color: Color(hex: "FF9CCC"), location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        )
        .font(.largeTitle.bold())

    }
}

#Preview {
    LandingView()
}
