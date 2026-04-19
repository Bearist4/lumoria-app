import SwiftUI

/// Lumoria's signature 7-point star — replaces the tittle on the
/// logotype "i", the notch in the logogram, and appears in
/// microinteractions (pull-to-refresh, export-done badge, share ghost,
/// empty states).
struct SevenPointStar: Shape {
    var innerRatio: CGFloat = 0.44

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * innerRatio
        let points = 7
        var path = Path()
        for i in 0..<(points * 2) {
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let angle = -CGFloat.pi / 2 + CGFloat(i) * (CGFloat.pi / CGFloat(points))
            let p = CGPoint(
                x: center.x + cos(angle) * r,
                y: center.y + sin(angle) * r
            )
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    SevenPointStar()
        .fill(Color.primary)
        .frame(width: 64, height: 64)
        .padding(32)
}
