import SwiftUI

/// Lumoria loader — a 104pt rounded square with a 7-point star at its
/// centre. Pass `value` (0...1) when progress is known; pass `nil` for
/// an indeterminate spinner (the star rotates slowly).
///
/// Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1766-52914
struct LumoriaLoader: View {

    /// `0...1` when progress is known, `nil` for indeterminate.
    var value: Double? = nil
    /// Outer box size. Defaults to the Figma reference (104pt).
    var size: CGFloat = 104

    @State private var indeterminateAngle: Double = 0

    // Relative sizing from the Figma frame so the star + text scale
    // cleanly when `size` is overridden.
    private var cornerRadius: CGFloat { size * 24.0 / 104.0 }
    private var starSize: CGFloat { size * 49.0 / 104.0 }
    private var textSize: CGFloat { size * 11.0 / 104.0 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.1))

            SevenPointStar()
                .fill(Color.black)
                .frame(width: starSize, height: starSize)
                .rotationEffect(.degrees(value == nil ? indeterminateAngle : 0))

            if let value {
                Text("\(Int((value * 100).rounded()))%")
                    .font(.system(size: textSize, weight: .semibold))
                    .tracking(0.06 * size / 104)
                    .foregroundStyle(.white)
                    .frame(width: starSize, height: starSize)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            guard value == nil, !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                indeterminateAngle = 360
            }
        }
    }
}

#Preview("Determinate 10%") {
    LumoriaLoader(value: 0.1)
        .padding()
}

#Preview("Indeterminate") {
    LumoriaLoader()
        .padding()
}
