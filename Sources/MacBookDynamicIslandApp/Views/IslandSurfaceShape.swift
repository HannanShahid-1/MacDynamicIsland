import SwiftUI

struct IslandSurfaceShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let topRadius = min(topRadius, rect.width / 2, rect.height / 2)
        let bottomRadius = min(bottomRadius, rect.width / 2, rect.height / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topRadius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY))

        if topRadius > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + topRadius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topRadius))

        if topRadius > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + topRadius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }

        path.closeSubpath()

        return path
    }
}

struct IslandBackdrop: View {
    let topRadius: CGFloat
    let bottomRadius: CGFloat
    let backgroundColor: Color

    var body: some View {
        let radius = bottomRadius

        IslandSurfaceShape(topRadius: topRadius, bottomRadius: bottomRadius)
            .fill(backgroundColor)
            .shadow(color: Color.black.opacity(radius > 24 ? 0.0 : 0.28), radius: radius > 24 ? 0 : 5, x: 0, y: radius > 24 ? 0 : 2)
    }
}
