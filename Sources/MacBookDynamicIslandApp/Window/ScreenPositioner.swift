import AppKit

enum ScreenPositioner {
    static func frame(for size: CGSize, on preferredScreen: NSScreen?) -> CGRect {
        let screen = preferredScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else {
            return CGRect(origin: .zero, size: size)
        }

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let notchCenterX = notchAwareCenterX(for: screen)
        let rawX = notchCenterX - (size.width / 2)
        let minX = visibleFrame.minX + IslandMetrics.sideMargin
        let maxX = visibleFrame.maxX - size.width - IslandMetrics.sideMargin
        let x = min(max(rawX, minX), maxX)
        let y = screenFrame.maxY - size.height + IslandMetrics.topInset

        return CGRect(
            x: x.rounded(.toNearestOrAwayFromZero),
            y: y.rounded(.toNearestOrAwayFromZero),
            width: size.width,
            height: size.height
        )
    }

    private static func notchAwareCenterX(for screen: NSScreen) -> CGFloat {
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea,
              !left.isEmpty,
              !right.isEmpty,
              left.maxX < right.minX else {
            return screen.frame.midX
        }

        return (left.maxX + right.minX) / 2
    }
}
