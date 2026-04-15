//
//  LandingView.swift
//  Lumoria App
//
//  Landing screen shown to unauthenticated users.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-8016
//

import SwiftUI

struct LandingView: View {
    @State private var showLogIn = false
    @State private var showSignUp = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()

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

                Text("By signing up, you agree to our Terms of Service and Privacy Policy. You confirm that your information is accurate and consent to our collection and use of your data as outlined.")
                    .font(.footnote)
                    .foregroundStyle(Color(hex: "A3A3A3"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Reserve height for pinned buttons + safe area
                Spacer().frame(height: 176)
            }

            // Pinned bottom CTAs
            VStack(spacing: 16) {
                Button("Log in") { showLogIn = true }
                    .lumoriaButtonStyle(.secondary)
                Button("Sign up") { showSignUp = true }
                    .lumoriaButtonStyle(.primary)
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
        Image("brand/default/logomark")
            .resizable()
            .scaledToFit()
            .frame(width: 137, height: 137)
    }

    // MARK: - Logotype

    private var logotypeView: some View {
        Image("brand/default/logo")
            .resizable()
            .scaledToFit()
    }

    // MARK: - Headline

    private var headlineView: some View {
        // "Tickets that last" black + "forever" with brand rainbow gradient
        // Gradient L→R: blue #57B7F5 · orange #FFA96C · yellow #FDDC51 · pink #FF9CCC
        (Text("Tickets that last ")
            .foregroundStyle(Color.black)
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
