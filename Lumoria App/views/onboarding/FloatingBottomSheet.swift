//
//  FloatingBottomSheet.swift
//  Lumoria App
//
//  Custom bottom-sheet presentation used by the onboarding sheets.
//  Native `.sheet` snaps to the screen edges and doesn't support a
//  horizontally-inset floating card. This modifier overlays a dim layer
//  + a content card with 19pt horizontal insets, flush to the bottom,
//  and a 36pt top corner radius (iPhone screen corner 55pt − 19pt inset).
//

import SwiftUI

private struct FloatingBottomSheetModifier<Sheet: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let sheet: () -> Sheet
    /// Dim the rest of the screen and block taps behind the card. Matches
    /// the system .sheet semantics for a non-dismissible tutorial cover.
    var interactiveDismiss: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack(alignment: .bottom) {
                    if isPresented {
                        Color.Overlay.sheet
                            .transition(.opacity)
                            .onTapGesture {
                                if interactiveDismiss { isPresented = false }
                            }

                        sheet()
                            .background(
                                RoundedRectangle(cornerRadius: 36, style: .continuous)
                                    .fill(Color.Background.default)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                            .padding(.horizontal, 19)
                            .padding(.bottom, 19)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                // Ignore container insets only (notch / home indicator)
                // so the card can bleed flush to screen edges, but keep
                // respecting the keyboard inset — when a TextField inside
                // the sheet focuses, the card rises above the keyboard
                // instead of being covered by it.
                .ignoresSafeArea(.container)
                // Animation must live OUTSIDE the if-condition so SwiftUI
                // sees the value flip and animates the appear, not just
                // the disappear.
                .animation(.spring(duration: 0.35), value: isPresented)
            }
    }
}

extension View {
    /// Presents a floating bottom-sheet with 19pt insets and a 36pt
    /// corner radius, matching the onboarding design spec.
    func floatingBottomSheet<Sheet: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Sheet
    ) -> some View {
        modifier(FloatingBottomSheetModifier(
            isPresented: isPresented,
            sheet: content
        ))
    }
}
