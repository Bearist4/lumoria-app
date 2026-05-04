import SwiftUI

/// Lumoria's signature 7-point star — exact curve set from the
/// canonical brand SVG (124×124 viewBox), normalised to fill any
/// rect. Rounded-bezier petals so the star reads as a seal/stamp
/// rather than a generic star. Same path the app icon uses, so
/// any in-app render morphs seamlessly into the icon artwork.
struct SevenPointStar: Shape {

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 124.0
        let sy = rect.height / 124.0
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()
        path.move(to: p(53.3927, 3.94481))
        path.addCurve(
            to: p(70.6076, 3.94481),
            control1: p(57.9744, -1.31494),
            control2: p(66.0258, -1.31494)
        )
        path.addLine(to: p(80.3975, 15.1835))
        path.addCurve(
            to: p(88.3876, 19.1114),
            control1: p(82.4406, 17.5289),
            control2: p(85.3176, 18.9431)
        )
        path.addLine(to: p(103.099, 19.9178))
        path.addCurve(
            to: p(113.832, 33.6575),
            control1: p(109.984, 20.2952),
            control2: p(115.004, 26.7213)
        )
        path.addLine(to: p(111.329, 48.4784))
        path.addCurve(
            to: p(113.302, 57.3043),
            control1: p(110.807, 51.5713),
            control2: p(111.517, 54.749)
        )
        path.addLine(to: p(121.857, 69.5486))
        path.addCurve(
            to: p(118.026, 86.6816),
            control1: p(125.861, 75.2789),
            control2: p(124.069, 83.2921)
        )
        path.addLine(to: p(105.115, 93.9243))
        path.addCurve(
            to: p(99.5854, 101.002),
            control1: p(102.42, 95.4357),
            control2: p(100.429, 97.9841)
        )
        path.addLine(to: p(95.5415, 115.464))
        path.addCurve(
            to: p(80.0313, 123.089),
            control1: p(93.6491, 122.232),
            control2: p(86.3949, 125.798)
        )
        path.addLine(to: p(66.4343, 117.3))
        path.addCurve(
            to: p(57.566, 117.3),
            control1: p(63.5967, 116.091),
            control2: p(60.4035, 116.091)
        )
        path.addLine(to: p(43.9687, 123.089))
        path.addCurve(
            to: p(28.4585, 115.464),
            control1: p(37.6051, 125.798),
            control2: p(30.3509, 122.232)
        )
        path.addLine(to: p(24.4146, 101.002))
        path.addCurve(
            to: p(18.8854, 93.9243),
            control1: p(23.5707, 97.9841),
            control2: p(21.5799, 95.4357)
        )
        path.addLine(to: p(5.97366, 86.6816))
        path.addCurve(
            to: p(2.14293, 69.5486),
            control1: p(-0.0690891, 83.2921),
            control2: p(-1.86074, 75.2789)
        )
        path.addLine(to: p(10.698, 57.3043))
        path.addCurve(
            to: p(12.6713, 48.4784),
            control1: p(12.4833, 54.749),
            control2: p(13.1937, 51.5713)
        )
        path.addLine(to: p(10.1677, 33.6575))
        path.addCurve(
            to: p(20.9012, 19.9178),
            control1: p(8.99611, 26.7213),
            control2: p(14.0162, 20.2952)
        )
        path.addLine(to: p(35.6126, 19.1114))
        path.addCurve(
            to: p(43.6025, 15.1835),
            control1: p(38.6827, 18.9431),
            control2: p(41.5594, 17.5289)
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
