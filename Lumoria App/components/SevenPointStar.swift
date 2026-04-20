import SwiftUI

/// Lumoria's signature 7-point star — the exact curve set from the
/// brand SVG (75×75 viewBox), normalised to fill any rect.
///
/// The path uses rounded-bezier petals rather than sharp triangles so
/// the star reads as a seal / stamp rather than a generic star.
struct SevenPointStar: Shape {

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 75.0
        let sy = rect.height / 75.0
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()
        path.move(to: p(32.0538, 2.36823))
        path.addCurve(
            to: p(42.3886, 2.36823),
            control1: p(34.8044, -0.78941),
            control2: p(39.638, -0.78941)
        )
        path.addLine(to: p(48.2659, 9.11529))
        path.addCurve(
            to: p(53.0627, 11.4734),
            control1: p(49.4925, 10.5233),
            control2: p(51.2196, 11.3723)
        )
        path.addLine(to: p(61.8946, 11.9575))
        path.addCurve(
            to: p(68.3382, 20.206),
            control1: p(66.0279, 12.1841),
            control2: p(69.0416, 16.0419)
        )
        path.addLine(to: p(66.8354, 29.1036))
        path.addCurve(
            to: p(68.02, 34.4021),
            control1: p(66.5217, 30.9604),
            control2: p(66.9482, 32.8681)
        )
        path.addLine(to: p(73.1558, 41.7529))
        path.addCurve(
            to: p(70.8561, 52.0386),
            control1: p(75.5594, 45.193),
            control2: p(74.4838, 50.0037)
        )
        path.addLine(to: p(63.1046, 56.3866))
        path.addCurve(
            to: p(59.7852, 60.6357),
            control1: p(61.487, 57.294),
            control2: p(60.2918, 58.8239)
        )
        path.addLine(to: p(57.3575, 69.3178))
        path.addCurve(
            to: p(48.0461, 73.8954),
            control1: p(56.2214, 73.3811),
            control2: p(51.8664, 75.522)
        )
        path.addLine(to: p(39.8832, 70.4197))
        path.addCurve(
            to: p(34.5592, 70.4197),
            control1: p(38.1797, 69.6944),
            control2: p(36.2627, 69.6944)
        )
        path.addLine(to: p(26.3962, 73.8954))
        path.addCurve(
            to: p(17.0848, 69.3178),
            control1: p(22.5759, 75.522),
            control2: p(18.2209, 73.3811)
        )
        path.addLine(to: p(14.6571, 60.6357))
        path.addCurve(
            to: p(11.3377, 56.3866),
            control1: p(14.1505, 58.8239),
            control2: p(12.9553, 57.294)
        )
        path.addLine(to: p(3.58623, 52.0386))
        path.addCurve(
            to: p(1.28649, 41.7529),
            control1: p(-0.0414772, 50.0037),
            control2: p(-1.11708, 45.193)
        )
        path.addLine(to: p(6.42247, 34.4021))
        path.addCurve(
            to: p(7.60708, 29.1036),
            control1: p(7.49424, 32.8681),
            control2: p(7.92072, 30.9604)
        )
        path.addLine(to: p(6.1041, 20.206))
        path.addCurve(
            to: p(12.5479, 11.9575),
            control1: p(5.40073, 16.0419),
            control2: p(8.41453, 12.1841)
        )
        path.addLine(to: p(21.3797, 11.4734))
        path.addCurve(
            to: p(26.1764, 9.11529),
            control1: p(23.2228, 11.3723),
            control2: p(24.9498, 10.5233)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 24) {
        SevenPointStar()
            .fill(Color.primary)
            .frame(width: 64, height: 64)

        SevenPointStar()
            .fill(Color.primary)
            .frame(width: 120, height: 120)
    }
    .padding(32)
}
