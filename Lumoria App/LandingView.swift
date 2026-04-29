//
//  LandingView.swift
//  Lumoria App
//
//  Landing screen shown to unauthenticated users.
//  Single "Get started" CTA that opens the morphing AuthFlowSheet.
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=948-8016
//

import SwiftUI

struct LandingView: View {
    @Environment(\.brandSlug) private var brandSlug
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var coordinator: AuthFlowCoordinator

    init(auth: AuthManager) {
        _coordinator = StateObject(wrappedValue: AuthFlowCoordinator(auth: auth))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.Background.default.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("brand/\(brandSlug)/logomark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 137, height: 137)

                Spacer().frame(height: 54)

                Image("brand/\(brandSlug)/logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 226, height: 90)
                    .opacity(0.3)

                headlineView

                Spacer().frame(height: 200)
            }

            VStack {
                Button("Get started") {
                    Analytics.track(.authFlowStarted)
                    coordinator.start()
                }
                .lumoriaButtonStyle(.primary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .navigationBarHidden(true)
        .floatingBottomSheet(isPresented: chooserBinding) {
            AuthChooserSheetContent(coordinator: coordinator)
        }
        .sheet(isPresented: modalBinding) {
            AuthFlowModalContent(coordinator: coordinator)
        }
    }

    /// True only while the coordinator wants the chooser visible.
    /// The setter swallows dismissals — actual dismiss flows through
    /// `coordinator.dismiss()` on the X tap.
    private var chooserBinding: Binding<Bool> {
        Binding(
            get: { coordinator.isPresented && coordinator.step == .chooser },
            set: { newValue in
                if !newValue && coordinator.step == .chooser {
                    coordinator.dismiss()
                }
            }
        )
    }

    /// True while the coordinator wants the email/login/signup modal.
    private var modalBinding: Binding<Bool> {
        Binding(
            get: { coordinator.isPresented && coordinator.step != .chooser },
            set: { newValue in
                if !newValue && coordinator.step != .chooser {
                    coordinator.dismiss()
                }
            }
        )
    }

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
    LandingView(auth: AuthManager())
}
