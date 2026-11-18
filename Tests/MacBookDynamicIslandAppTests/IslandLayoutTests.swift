import AppKit
import SwiftUI

import Testing
@testable import MacBookDynamicIslandApp

@MainActor
@Suite("Island layout")
struct IslandLayoutTests {
    /// Every size and layout combination the Options panel can produce.
    private func configurations() -> [(IslandLayoutMode, IslandSizeOption)] {
        IslandLayoutMode.allCases.flatMap { layout in
            IslandSizeOption.allCases.map { (layout, $0) }
        }
    }

    private func withConfiguration(
        _ layout: IslandLayoutMode,
        _ size: IslandSizeOption,
        _ body: (IslandStore) -> Void
    ) {
        let store = IslandStore()
        let original = (store.layoutMode, store.expandedSizeOption)
        defer { (store.layoutMode, store.expandedSizeOption) = original }

        store.layoutMode = layout
        store.expandedSizeOption = size
        body(store)
    }

    @Test func modeSwitcherKeepsItsScreenPositionAcrossModes() {
        for (layout, size) in configurations() {
            withConfiguration(layout, size) { store in
                // The island is centred on the notch, so a constant distance from each
                // mode's centre line means a constant position on screen.
                let distancesFromCentre = store.visibleModes.map { mode in
                    store.expandedSize(for: mode).width / 2 - store.modeSelectorTrailingEdge(in: mode)
                }

                for distance in distancesFromCentre {
                    #expect(abs(distance - distancesFromCentre[0]) < 0.001)
                }
            }
        }
    }

    @Test func modeSwitcherStaysInsideTheIslandAndClearOfTheNotch() {
        #expect(IslandMetrics.modeSelectorOrigin.y >= 0)
        #expect(IslandMetrics.modeSelectorOrigin.y + IslandMetrics.modeSelectorHeight <= IslandMetrics.notchSize.height)

        for (layout, size) in configurations() {
            withConfiguration(layout, size) { store in
                for mode in store.visibleModes {
                    let islandWidth = store.expandedSize(for: mode).width
                    let trailingEdge = store.modeSelectorTrailingEdge(in: mode)
                    let leadingEdge = trailingEdge - store.modeSelectorWidth
                    let notchLeadingEdge = (islandWidth - IslandMetrics.notchSize.width) / 2

                    #expect(leadingEdge >= IslandMetrics.modeSelectorOrigin.x - 0.001)
                    #expect(trailingEdge < notchLeadingEdge)
                }
            }
        }
    }

    @Test func tabContentArrivesFromTheSideItWasReachedFrom() {
        withConfiguration(.classicThreeModes, .standard) { store in
            store.showPlayerMode()

            store.showNBAMode()
            #expect(store.modeChangeDirection == 1)

            store.showPlayerMode()
            #expect(store.modeChangeDirection == -1)

            // Swiping back from the first mode wraps to the last one, but the
            // content still travels the way the swipe did.
            store.showPreviousMode()
            #expect(store.islandMode == .workspace)
            #expect(store.modeChangeDirection == -1)

            store.showNextMode()
            #expect(store.islandMode == .player)
            #expect(store.modeChangeDirection == 1)
        }
    }

    @Test func windowLeavesRoomForTheBounciestOpening() {
        // The opening spring overshoots by roughly 5.5% of the distance travelled.
        // The window's transparent margin has to cover that for the largest jump:
        // from the notch to the biggest island any configuration can produce.
        let overshoot = 0.06
        let compact = IslandMetrics.playerCompactSize

        for (layout, size) in configurations() {
            withConfiguration(layout, size) { store in
                for mode in store.visibleModes {
                    let expanded = store.expandedSize(for: mode)
                    #expect((expanded.width - compact.width) * overshoot / 2 <= IslandMetrics.motionOverscan.width)
                    #expect((expanded.height - compact.height) * overshoot <= IslandMetrics.motionOverscan.height)
                }
            }
        }

        let tallest = IslandMetrics.nbaBoxScoreLargeExpandedSize
        #expect((tallest.height - compact.height) * overshoot <= IslandMetrics.motionOverscan.height)
    }

    private func hostedRow(contentWidth: CGFloat) -> NSView {
        let row = ScrollView(.horizontal, showsIndicators: false) {
            Color.red.frame(width: contentWidth, height: 40)
        }
        .frame(width: 300, height: 40)
        .frame(width: 300, height: 120, alignment: .bottom)

        let hosting = NSHostingView(rootView: row)
        hosting.frame = CGRect(x: 0, y: 0, width: 300, height: 120)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        hosting.layoutSubtreeIfNeeded()
        return hosting
    }

    @Test func sidewaysSwipeBelongsToARowThatScrollsSideways() {
        _ = NSApplication.shared
        let view = hostedRow(contentWidth: 900)

        // The row occupies the bottom 40 points of the window (window coordinates start at the bottom).
        #expect(ScrollHitTesting.isOverHorizontallyScrollableContent(CGPoint(x: 150, y: 20), in: view))
        #expect(!ScrollHitTesting.isOverHorizontallyScrollableContent(CGPoint(x: 150, y: 100), in: view))
    }

    @Test func rowThatAlreadyFitsDoesNotClaimSwipes() {
        _ = NSApplication.shared
        let view = hostedRow(contentWidth: 200)

        #expect(!ScrollHitTesting.isOverHorizontallyScrollableContent(CGPoint(x: 150, y: 20), in: view))
    }
}
