import SwiftUI

struct PlayerDashboardView: View {
    @ObservedObject var store: IslandStore

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            NowPlayingCardView(store: store)
                .frame(width: nowPlayingWidth)
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(.leading, 24)
                .padding(.trailing, nowPlayingTrailingClearance)

            PlayerCalendarDivider()

            CalendarWidgetView(store: store, showsWeather: store.showHomeWeather)
                .padding(.leading, 14)
                .padding(.trailing, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var nowPlayingWidth: CGFloat {
        store.expandedSizeOption == .large ? 344 : 286
    }

    private var nowPlayingTrailingClearance: CGFloat {
        store.expandedSizeOption == .large ? 24 : 18
    }
}

struct PlayerCalendarDivider: View {
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        LinearGradient(
            colors: [
                islandTextColor.opacity(0.0),
                islandTextColor.opacity(0.18),
                islandTextColor.opacity(0.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 1, height: 88)
    }
}
