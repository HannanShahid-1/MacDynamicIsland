import MacBookDynamicIslandCore
import SwiftUI

struct HomeNBAScoresWidget: View {
    @ObservedObject var store: IslandStore
    let reservesWeatherSpace: Bool
    @State private var isMessageButtonHovered = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if !store.nbaScoresEnabled {
                compactMessage(
                    systemName: "basketball",
                    title: "NBA scores off",
                    detail: "Enable the no-key scoreboard",
                    buttonTitle: "Enable",
                    action: store.enableNBAScores
                )
            } else if store.nbaScoreboard == nil && store.nbaScoresStatus == .loading {
                VStack(alignment: .leading, spacing: 7) {
                    NBASkeletonBlock(width: nil, height: 36)
                    NBASkeletonBlock(width: nil, height: 36)
                }
            } else if let scoreboard = store.nbaScoreboard, scoreboard.games.isEmpty {
                compactMessage(
                    systemName: "calendar.badge.clock",
                    title: "No games today",
                    detail: "Next slate will appear here",
                    buttonTitle: nil,
                    action: nil
                )
            } else if store.nbaGames.isEmpty {
                compactMessage(
                    systemName: "wifi.exclamationmark",
                    title: "Scores unavailable",
                    detail: "No cached scores yet",
                    buttonTitle: "Retry",
                    action: store.refreshNBAFromUserAction
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(store.nbaGames.prefix(2))) { game in
                        HomeNBAGameLine(game: game)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "basketball.fill")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color(red: 0.96, green: 0.42, blue: 0.18))

            VStack(alignment: .leading, spacing: 1) {
                Text("NBA Today")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                Text(updateText)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(islandTextColor.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            NBAStatusPill(statusText: pillText, isLive: store.nbaScoreboard?.hasLiveGame == true)
                .opacity(reservesWeatherSpace ? 0 : 1)

            if reservesWeatherSpace {
                Color.clear.frame(width: 60, height: 1)
            }
        }
        .frame(height: 32)
    }

    private func compactMessage(
        systemName: String,
        title: String,
        detail: String,
        buttonTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(islandTextColor.opacity(0.46))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if let buttonTitle, let action {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Capsule().fill(Color.white.opacity(isMessageButtonHovered ? 0.17 : 0.11)))
                        .scaleEffect(isMessageButtonHovered ? 1.05 : 1)
                }
                .buttonStyle(IslandButtonPressStyle())
                .onHover { hovering in
                    withAnimation(IslandMotion.hover) {
                        isMessageButtonHovered = hovering
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
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

struct HomeNBAGameLine: View {
    let game: NBAGameSummary
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 8) {
            teamText(game.awayTeam)
            Text("@")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(islandTextColor.opacity(0.34))
            teamText(game.homeTeam)

            Spacer(minLength: 6)

            Text(game.displayStatus)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(islandTextColor.opacity(0.075), lineWidth: 1)
        }
    }

    private func teamText(_ team: NBATeamSummary) -> some View {
        HStack(spacing: 4) {
            Text(team.tricode)
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                .lineLimit(1)
            Text(game.hasScore ? "\(team.score)" : "--")
                .font(.system(size: 11.5, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(islandTextColor.opacity(game.hasScore ? 0.92 : 0.36))
                .lineLimit(1)
        }
        .frame(width: 56, alignment: .leading)
    }

    private var statusColor: Color {
        game.status.isLive ? Color.green.opacity(0.92) : islandTextColor.opacity(0.54)
    }
}
