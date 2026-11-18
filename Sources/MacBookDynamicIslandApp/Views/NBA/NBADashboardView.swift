import MacBookDynamicIslandCore
import SwiftUI

enum NBADashboardSizing {
    case mode
    case home
}

struct NBADashboardView: View {
    @ObservedObject var store: IslandStore
    var sizing: NBADashboardSizing = .mode
    var reservesWeatherSpace = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        let expandedSize = sizing == .home ? store.expandedSize(for: .player) : store.expandedSize(for: .nba)
        let contentHeight = expandedSize.height - 26

        VStack(alignment: .leading, spacing: 8) {
            topBar
                .padding(.leading, topBarLeadingPadding)
                .padding(.trailing, reservesWeatherSpace ? 76 : 4)

            dashboardContent
        }
        .frame(width: expandedSize.width - 28, height: contentHeight, alignment: .topLeading)
        .padding(.top, sizing == .home ? 16 : 1)
    }

    /// Starts the title clear of the mode switcher, which shares the top band.
    private var topBarLeadingPadding: CGFloat {
        let mode: IslandMode = sizing == .home ? .player : .nba
        let contentLeading = IslandMetrics.expandedContentInsets(for: mode).leading
        return max(98, store.modeSelectorTrailingEdge(in: mode) - contentLeading + 14)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("NBA Today")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .lineLimit(1)

                Text(updateText)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(islandTextColor.opacity(0.48))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            NBAStatusPill(statusText: pillText, isLive: store.nbaScoreboard?.hasLiveGame == true)

            IconButton(systemName: "arrow.clockwise", title: "Refresh NBA scores") {
                store.refreshNBAFromUserAction()
            }
            .disabled(!store.nbaScoresEnabled || store.nbaScoresStatus == .loading)
        }
        .frame(height: 32)
    }

    @ViewBuilder
    private var dashboardContent: some View {
        if !store.nbaScoresEnabled {
            NBAEmptyStateView(
                systemName: "basketball",
                title: "NBA scores off",
                detail: "Enable the free no-key scoreboard",
                buttonTitle: "Enable",
                action: store.enableNBAScores
            )
        } else if store.nbaScoreboard == nil && store.nbaScoresStatus == .loading {
            NBALoadingView()
        } else if let scoreboard = store.nbaScoreboard, scoreboard.games.isEmpty {
            NBAEmptyStateView(
                systemName: "calendar.badge.clock",
                title: "No NBA games today",
                detail: "Check back on the next slate",
                buttonTitle: nil,
                action: nil
            )
        } else if store.nbaGames.isEmpty {
            NBAEmptyStateView(
                systemName: "wifi.exclamationmark",
                title: "Scores unavailable",
                detail: "No cached scores yet",
                buttonTitle: "Retry",
                action: store.refreshNBAFromUserAction
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if case .failed = store.nbaScoresStatus {
                    HStack(spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Scores unavailable")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Color.yellow.opacity(0.84))
                    .frame(height: 13)
                }

                gameStrip
                    .frame(height: 68)

                if store.selectedNBAGame != nil {
                    NBABoxScorePanel(store: store)
                        .transition(.islandPop(scale: 0.94, anchor: .top))
                }
            }
        }
    }

    private var gameStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.nbaGames) { game in
                    NBAGameCapsule(
                        game: game,
                        isSelected: store.selectedNBAGameID == game.id
                    ) {
                        withAnimation(IslandMotion.select) {
                            store.selectNBAGame(game)
                        }
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private var updateText: String {
        if let updatedAt = store.nbaScoreboard?.updatedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Updated \(formatter.string(from: updatedAt))"
        }

        return store.nbaOptionsStatusText
    }

    private var pillText: String {
        if store.nbaScoreboard?.hasLiveGame == true {
            return "Live"
        }

        if let scoreboard = store.nbaScoreboard, !scoreboard.games.isEmpty {
            return "Today"
        }

        switch store.nbaScoresStatus {
        case .disabled:
            return "Off"
        case .loading:
            return "Loading"
        case .failed:
            return "Error"
        case .idle, .available:
            return "Ready"
        }
    }
}

struct NBAStatusPill: View {
    let statusText: String
    let isLive: Bool
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isLive ? Color.green : Color.white.opacity(0.42))
                .frame(width: 6, height: 6)
                .background {
                    if isLive {
                        Circle()
                            .stroke(Color.green.opacity(isPulsing ? 0.0 : 0.55), lineWidth: 1.4)
                            .scaleEffect(isPulsing ? 2.6 : 1.0)
                    }
                }
                .onAppear(perform: syncPulse)
                .onChange(of: isLive) { _ in
                    syncPulse()
                }

            Text(statusText)
                .font(.system(size: 10.5, weight: .black, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(
            Capsule()
                .fill(Color.white.opacity(isLive ? 0.10 : 0.065))
        )
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(isLive ? 0.16 : 0.09), lineWidth: 1)
        }
    }

    private func syncPulse() {
        guard isLive else {
            isPulsing = false
            return
        }

        isPulsing = false
        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
            isPulsing = true
        }
    }
}

struct NBAGameCapsule: View {
    let game: NBAGameSummary
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 8) {
                    teamBlock(team: game.awayTeam)
                    Text("@")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(islandTextColor.opacity(0.32))
                        .padding(.top, 3)
                    teamBlock(team: game.homeTeam)
                }

                HStack(spacing: 5) {
                    Text(game.displayStatus)
                        .font(.system(size: 10.2, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    if let seriesText = game.seriesText {
                        Text(seriesText)
                            .font(.system(size: 9.2, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(islandTextColor.opacity(0.46))
                    }
                }
            }
            .padding(.horizontal, 11)
            .frame(width: 166, height: 64, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(fillOpacity))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? 1.2 : 1)
            }
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(IslandButtonPressStyle())
        .help("\(game.awayTeam.tricode) at \(game.homeTeam.tricode)")
        .onHover { hovering in
            withAnimation(IslandMotion.hover) {
                isHovered = hovering
            }
        }
    }

    private var fillOpacity: CGFloat {
        if isSelected { return 0.13 }
        return isHovered ? 0.09 : 0.055
    }

    private func teamBlock(team: NBATeamSummary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            teamLine(team: team)
            Text(team.name)
                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .foregroundStyle(islandTextColor.opacity(0.56))
                .frame(width: 58, height: 18, alignment: .topLeading)
                .accessibilityLabel("\(team.city) \(team.name)")
        }
        .frame(width: 58, alignment: .leading)
    }

    private func teamLine(team: NBATeamSummary) -> some View {
        HStack(spacing: 4) {
            Text(team.tricode)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .lineLimit(1)
            Text(game.hasScore ? "\(team.score)" : "--")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(islandTextColor.opacity(game.hasScore ? 0.92 : 0.36))
        }
    }

    private var borderColor: Color {
        if isSelected {
            return Color(red: 0.96, green: 0.42, blue: 0.18).opacity(0.70)
        }

        return islandTextColor.opacity(isHovered ? 0.16 : 0.09)
    }
}
