import SwiftUI

enum IslandMetrics {
    static let playerCompactSize = CGSize(width: 180, height: 30)
    static let playerExpandedSize = CGSize(width: 690, height: 126)
    static let playerLargeExpandedSize = CGSize(width: 790, height: 164)
    static let customHomeTwoWidgetSize = CGSize(width: 760, height: 154)
    static let customHomeTwoWidgetLargeSize = CGSize(width: 840, height: 180)
    static let customHomeThreeWidgetSize = CGSize(width: 850, height: 164)
    static let customHomeThreeWidgetLargeSize = CGSize(width: 910, height: 184)
    static let nbaExpandedSize = CGSize(width: 740, height: 134)
    static let nbaLargeExpandedSize = CGSize(width: 820, height: 134)
    static let nbaBoxScoreExpandedSize = CGSize(width: 740, height: 372)
    static let nbaBoxScoreLargeExpandedSize = CGSize(width: 820, height: 446)
    static let compactSize = CGSize(width: 300, height: 30)
    static let airPodsSize = CGSize(width: 340, height: 30)
    static let chargingSize = CGSize(width: 360, height: 30)
    static let systemControlSize = CGSize(width: 350, height: 30)
    static let dragSize = CGSize(width: 700, height: 154)
    static let expandedSize = CGSize(width: 740, height: 184)
    static let largeExpandedSize = CGSize(width: 840, height: 216)
    static let notchCoreWidth: CGFloat = 190
    static let compactTopRadius: CGFloat = 0
    static let compactBottomRadius: CGFloat = 13
    static let airPodsTopRadius: CGFloat = 10
    static let airPodsBottomRadius: CGFloat = 15
    static let chargingTopRadius: CGFloat = 10
    static let chargingBottomRadius: CGFloat = 15
    static let systemControlTopRadius = compactTopRadius
    static let systemControlBottomRadius = compactBottomRadius
    static let expandedBottomRadius: CGFloat = 28
    static let topInset: CGFloat = 0
    static let sideMargin: CGFloat = 16

    /// How much the compact island swells under the pointer when it opens on click
    /// rather than on hover: enough to poke out from behind the notch.
    static let hoverPeekGrowth = CGSize(width: 28, height: 7)
    static let hoverPeekBottomRadiusGrowth: CGFloat = 4

    /// Transparent room the window keeps beyond the island's resting size, on each
    /// side and below, so a spring can overshoot without being cut off at the
    /// window's edge. Sized for the largest jump (notch to the biggest expanded
    /// size) at the bounciest spring in `IslandMotion`.
    static let motionOverscan = CGSize(width: 36, height: 32)

    /// The MacBook notch at default display scaling, in points. The expanded
    /// island's top band of this height sits level with the menu bar, and
    /// anything drawn behind the notch itself cannot be seen.
    static let notchSize = CGSize(width: 185, height: 32)

    static let modeSelectorHeight: CGFloat = 20

    /// Top-left corner of the mode switcher inside the narrowest expanded mode:
    /// left of the notch and vertically centred in the menu bar band, like a
    /// menu bar item. Wider modes keep it at the same place on screen; see
    /// `IslandStore.modeSelectorCenterOffset`.
    static let modeSelectorOrigin = CGPoint(
        x: 19,
        y: (notchSize.height - modeSelectorHeight) / 2
    )

    static func expandedContentInsets(for mode: IslandMode) -> EdgeInsets {
        switch mode {
        case .player:
            return EdgeInsets(top: 14, leading: 14, bottom: 11, trailing: 14)
        case .nba, .workspace:
            return EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        }
    }
}
