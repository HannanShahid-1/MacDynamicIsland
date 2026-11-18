import SwiftUI

struct CustomHomeDashboardView: View {
    @ObservedObject var store: IslandStore

    var body: some View {
        let widgets = store.visibleHomeWidgets

        ZStack(alignment: .topTrailing) {
            if widgets == [.nbaScores] {
                NBADashboardView(
                    store: store,
                    sizing: .home,
                    reservesWeatherSpace: store.showHomeWeather
                )
            } else {
                widgetGrid(widgets)
            }

            if store.showHomeWeather {
                WeatherMiniWidgetView(store: store)
                    .padding(.top, 1)
                    .padding(.trailing, 2)
                    .transition(.islandPop(scale: 0.7, anchor: .topTrailing))
            }
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        .animation(IslandMotion.rearrange, value: store.homeWidgets)
        .animation(IslandMotion.pop, value: store.showHomeWeather)
    }

    private var contentSize: CGSize {
        let expandedSize = store.expandedSize(for: .player)
        return CGSize(width: expandedSize.width - 28, height: expandedSize.height - 25)
    }

    private func widgetGrid(_ widgets: [HomeWidget]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(widgets.enumerated()), id: \.element) { index, widget in
                if index > 0 {
                    HomeWidgetDivider()
                        .frame(height: dividerHeight(for: widgets.count))
                }

                HomeWidgetPanel(
                    store: store,
                    widget: widget,
                    index: index,
                    count: widgets.count,
                    reservesWeatherSpace: store.showHomeWeather && widgets.last == widget
                )
                .frame(width: widgetWidth(for: widgets.count), height: contentSize.height)
                .transition(.islandPop(scale: 0.92))
            }
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        .background(HomeFlowSurface())
    }

    private func widgetWidth(for count: Int) -> CGFloat {
        let spacing = CGFloat(max(0, count - 1))
        return (contentSize.width - spacing) / CGFloat(max(count, 1))
    }

    private func dividerHeight(for count: Int) -> CGFloat {
        count >= 3 ? contentSize.height - 28 : contentSize.height - 38
    }
}

struct HomeWidgetPanel: View {
    @ObservedObject var store: IslandStore
    let widget: HomeWidget
    let index: Int
    let count: Int
    let reservesWeatherSpace: Bool
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        content
            .padding(panelPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch widget {
        case .appleMusic:
            NowPlayingCardView(store: store)
                .padding(.horizontal, count == 1 ? 16 : 4)
                .padding(.trailing, reservesWeatherSpace ? 58 : 0)
        case .calendar:
            CalendarWidgetView(
                store: store,
                showsWeather: false,
                reservesWeatherSpace: false
            )
        case .nbaScores:
            HomeNBAScoresWidget(store: store, reservesWeatherSpace: reservesWeatherSpace)
        }
    }

    private var panelPadding: EdgeInsets {
        if count == 1 {
            return EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        }

        return EdgeInsets(
            top: topInset,
            leading: horizontalInset,
            bottom: count >= 3 ? 4 : 8,
            trailing: horizontalInset
        )
    }

    private var horizontalInset: CGFloat {
        count >= 3 ? 12 : 16
    }

    private var topInset: CGFloat {
        if count >= 3 {
            return 16
        }

        return 12
    }
}

struct HomeFlowSurface: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.020),
                Color.white.opacity(0.006),
                Color.white.opacity(0.018)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .allowsHitTesting(false)
    }
}

struct HomeWidgetDivider: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(0.09),
                Color.white.opacity(0.035),
                Color.white.opacity(0.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 1)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .allowsHitTesting(false)
    }
}
