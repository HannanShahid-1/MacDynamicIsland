import SwiftUI

struct IslandOptionsPopoverView: View {
    @ObservedObject var store: IslandStore
    @State private var selectedTab: IslandOptionsTab = .appearance
    @State private var isCloseHovered = false
    @State private var isResetHovered = false
    @Namespace private var sidebarSelectionNamespace

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()
                .overlay(Color.white.opacity(0.10))

            activePanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(28)
        }
        .frame(width: 840, height: 500)
        .foregroundStyle(Color.white)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.055, green: 0.058, blue: 0.066).opacity(0.98),
                            Color(red: 0.030, green: 0.032, blue: 0.038).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.38), radius: 26, x: 0, y: 16)
        .environment(\.colorScheme, .dark)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 11) {
                Button {
                    store.pauseAmbientRefreshes(for: 0.34)
                    store.isOptionsPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .black))
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(isCloseHovered ? 0.16 : 0.10))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isCloseHovered ? 0.18 : 0.12), lineWidth: 1)
                        )
                        .rotationEffect(.degrees(isCloseHovered ? 90 : 0))
                        .scaleEffect(isCloseHovered ? 1.08 : 1)
                        .contentShape(Circle())
                }
                .buttonStyle(IslandButtonPressStyle(pressedScale: 0.86))
                .help("Close options")
                .onHover { hovering in
                    withAnimation(IslandMotion.hover) {
                        isCloseHovered = hovering
                    }
                }

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Options")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                    Text("Island")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.44))
                }
            }
            .padding(.top, 4)

            VStack(spacing: 6) {
                ForEach(IslandOptionsTab.allCases) { tab in
                    OptionsSidebarButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        selectionNamespace: sidebarSelectionNamespace
                    ) {
                        withAnimation(IslandMotion.select) {
                            selectedTab = tab
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(IslandMotion.rearrange) {
                    store.resetAppearance()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .bold))
                    Text("Reset")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(isResetHovered ? 0.11 : 0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(isResetHovered ? 0.15 : 0.10), lineWidth: 1)
                )
            }
            .buttonStyle(IslandButtonPressStyle())
            .help("Reset options")
            .onHover { hovering in
                withAnimation(IslandMotion.hover) {
                    isResetHovered = hovering
                }
            }
        }
        .padding(22)
        .frame(width: 220)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.18))
    }

    private var activePanel: some View {
        ZStack(alignment: .topLeading) {
            switch selectedTab {
            case .appearance:
                appearancePanel
                    .transition(panelTransition)
            case .home:
                homePanel
                    .transition(panelTransition)
            case .behavior:
                behaviorPanel
                    .transition(panelTransition)
            case .weather:
                weatherPanel
                    .transition(panelTransition)
            case .sports:
                sportsPanel
                    .transition(panelTransition)
            }
        }
    }

    private var panelTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .offset(y: 14))
                .combined(with: .scale(scale: 0.98, anchor: .top)),
            removal: .opacity.animation(IslandMotion.contentOut)
        )
    }

    private var homePanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            OptionsPanelHeader(
                title: "Home UI",
                detail: "First screen and two-UI mode",
                systemName: "rectangle.grid.2x2"
            )

            OptionsSection(title: "Mode") {
                OptionsSettingRow(title: "Layout mode") {
                    Picker("", selection: $store.layoutMode) {
                        ForEach(IslandLayoutMode.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                }
            }

            OptionsSection(title: "First UI") {
                HomeWidgetLayoutEditor(store: store)
            }

            OptionsSection(title: "Weather") {
                OptionsToggleRow(
                    systemName: "cloud.sun",
                    title: "Show weather",
                    detail: "Keep weather as a small first-UI widget",
                    isOn: $store.showHomeWeather
                )
            }

            Spacer(minLength: 0)
        }
    }

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            OptionsPanelHeader(
                title: "Appearance",
                detail: "Colors and island scale",
                systemName: "paintpalette"
            )

            OptionsSection(title: "Theme") {
                OptionsSettingRow(title: "Background") {
                    HStack(spacing: 11) {
                        ForEach(IslandBackgroundOption.allCases) { option in
                            ColorSwatchButton(
                                title: option.title,
                                color: option.color,
                                isSelected: store.backgroundOption == option
                            ) {
                                withAnimation(IslandMotion.select) {
                                    store.backgroundOption = option
                                }
                            }
                        }
                    }
                }

                OptionsSettingRow(title: "Text") {
                    HStack(spacing: 11) {
                        ForEach(IslandTextOption.allCases) { option in
                            ColorSwatchButton(
                                title: option.title,
                                color: option.color,
                                isSelected: store.textOption == option
                            ) {
                                withAnimation(IslandMotion.select) {
                                    store.textOption = option
                                }
                            }
                        }
                    }
                }
            }

            OptionsSection(title: "Layout") {
                OptionsSettingRow(title: "Expanded size") {
                    Picker("", selection: $store.expandedSizeOption) {
                        ForEach(IslandSizeOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var behaviorPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            OptionsPanelHeader(
                title: "Behavior",
                detail: "Interaction preferences",
                systemName: "cursorarrow.motionlines"
            )

            OptionsSection(title: "Pointer") {
                OptionsToggleRow(
                    systemName: "cursorarrow.rays",
                    title: "Hover expand",
                    detail: "Open the island from the compact view",
                    isOn: $store.autoExpandOnHover
                )
            }

            Spacer(minLength: 0)
        }
    }

    private var weatherPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            OptionsPanelHeader(
                title: "Weather",
                detail: "Manual city weather",
                systemName: "cloud.sun"
            )

            OptionsSection(title: "Location") {
                WeatherLocationSettingView(store: store)
            }

            Spacer(minLength: 0)
        }
    }

    private var sportsPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            OptionsPanelHeader(
                title: "Sports",
                detail: "Optional NBA scores",
                systemName: "basketball"
            )

            OptionsSection(title: "NBA") {
                NBAScoresSettingView(store: store)
            }

            Spacer(minLength: 0)
        }
    }
}

enum IslandOptionsTab: String, CaseIterable, Identifiable {
    case appearance
    case home
    case behavior
    case weather
    case sports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance:
            return "Appearance"
        case .home:
            return "Home UI"
        case .behavior:
            return "Behavior"
        case .weather:
            return "Weather"
        case .sports:
            return "Sports"
        }
    }

    var systemName: String {
        switch self {
        case .appearance:
            return "paintpalette"
        case .home:
            return "rectangle.grid.2x2"
        case .behavior:
            return "cursorarrow.motionlines"
        case .weather:
            return "cloud.sun"
        case .sports:
            return "basketball"
        }
    }
}
