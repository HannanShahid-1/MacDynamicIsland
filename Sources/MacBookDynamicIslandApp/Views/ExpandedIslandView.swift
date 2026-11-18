import SwiftUI

struct ExpandedIslandView: View {
    @ObservedObject var store: IslandStore
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        // Centred, so modes of different widths each stay centred on the notch
        // while one replaces the other.
        ZStack(alignment: .top) {
            switch store.islandMode {
            case .player:
                if store.layoutMode == .customTwoModes {
                    CustomHomeDashboardView(store: store)
                        .transition(modeTransition)
                } else {
                    PlayerDashboardView(store: store)
                        .transition(modeTransition)
                }
            case .nba:
                NBADashboardView(store: store)
                    .transition(modeTransition)
            case .workspace:
                workspaceContent
                    .transition(modeTransition)
            }
        }
        .foregroundStyle(islandTextColor)
        .animation(IslandMotion.tabContent, value: store.islandMode)
    }

    private var modeTransition: AnyTransition {
        .islandTab(direction: store.modeChangeDirection)
    }

    private var workspaceContent: some View {
        let contentSize = workspaceContentSize

        return ZStack(alignment: .topLeading) {
            HStack(alignment: .top, spacing: 12) {
                ClipboardDock(store: store)
                    .frame(width: workspaceClipboardWidth, height: contentSize.height)

                FileShelfGallery(store: store)
                    .frame(
                        width: contentSize.width - workspaceClipboardWidth - 12,
                        height: contentSize.height
                    )
            }
            .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
    }

    private var workspaceContentSize: CGSize {
        let expandedSize = store.expandedSize(for: .workspace)
        return CGSize(width: expandedSize.width - 32, height: expandedSize.height - 22)
    }

    private var workspaceClipboardWidth: CGFloat {
        store.expandedSizeOption == .large ? 224 : 196
    }
}
