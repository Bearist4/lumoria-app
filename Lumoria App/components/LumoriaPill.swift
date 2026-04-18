//
//  LumoriaPill.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=276-4288
//
//  Short-lived toast pill: dark rounded capsule with a white semibold label.
//  Paired with `.lumoriaToast(…)` to fade in, stick for a few seconds, fade out.
//

import SwiftUI

// MARK: - Pill view

struct LumoriaPill: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.Button.Primary.Label.default)
            .lineLimit(1)
            .padding(.horizontal, 32)
            .frame(height: 40)
            .background(
                Capsule().fill(Color.Button.Primary.Background.default)
            )
            .overlay(
                Capsule().stroke(Color.Button.Primary.Label.default.opacity(0.5), lineWidth: 1)
            )
    }
}

// MARK: - Toast modifier

extension View {
    /// Shows a `LumoriaPill` anchored near the bottom of the view while `text`
    /// is non-nil, then clears `text` after `duration` seconds.
    func lumoriaToast(
        _ text: Binding<String?>,
        duration: TimeInterval = 2.0
    ) -> some View {
        modifier(LumoriaToastModifier(text: text, duration: duration))
    }
}

private struct LumoriaToastModifier: ViewModifier {
    @Binding var text: String?
    let duration: TimeInterval

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let text {
                    LumoriaPill(label: text)
                        .padding(.bottom, 24)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .task(id: text) {
                            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                            withAnimation(.easeInOut(duration: 0.2)) {
                                self.text = nil
                            }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: text)
    }
}

// MARK: - Preview

#Preview("Pill") {
    VStack {
        Spacer()
        LumoriaPill(label: "Ticket added to Ski Trip 2024")
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.Background.default)
}
