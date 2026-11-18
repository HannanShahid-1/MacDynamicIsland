import MacBookDynamicIslandCore
import SwiftUI

struct NBABoxScorePanel: View {
    @ObservedObject var store: IslandStore
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let selectedGame = store.selectedNBAGame {
                panelHeader(for: selectedGame)

                if store.nbaBoxScoreStatus == .loading && store.nbaBoxScore == nil {
                    NBAPlayerRowsLoadingView()
                } else if let boxScore = store.nbaBoxScore, boxScore.gameId == selectedGame.id {
                    playerRows(for: boxScore)
                } else if case .failed = store.nbaBoxScoreStatus {
                    NBAInlineMessage(systemName: "wifi.exclamationmark", text: "Box score unavailable")
                } else {
                    Text("Box score unavailable")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .foregroundStyle(islandTextColor.opacity(0.50))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.052))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(islandTextColor.opacity(0.08), lineWidth: 1)
        }
    }

    private func panelHeader(for game: NBAGameSummary) -> some View {
        HStack(spacing: 8) {
            Text("\(game.awayTeam.tricode) @ \(game.homeTeam.tricode)")
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                .lineLimit(1)

            Spacer(minLength: 6)

            NBABoxSideButton(title: game.awayTeam.tricode, side: .away, selectedSide: $store.nbaBoxScoreSide)
            NBABoxSideButton(title: game.homeTeam.tricode, side: .home, selectedSide: $store.nbaBoxScoreSide)
        }
        .frame(height: 21)
    }

    private func playerRows(for boxScore: NBABoxScore) -> some View {
        let team = store.nbaBoxScoreSide == .away ? boxScore.awayTeam : boxScore.homeTeam

        return VStack(spacing: 4) {
            NBAStatHeaderRow(teamTricode: team.tricode)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 3) {
                    ForEach(team.players) { player in
                        NBAPlayerStatRow(player: player)
                    }
                }
            }
        }
    }
}

struct NBABoxSideButton: View {
    let title: String
    let side: NBABoxScoreSide
    @Binding var selectedSide: NBABoxScoreSide
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(IslandMotion.select) {
                selectedSide = side
            }
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .frame(width: 42, height: 20)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(fillOpacity))
                )
                .scaleEffect(isHovered && selectedSide != side ? 1.05 : 1)
        }
        .buttonStyle(IslandButtonPressStyle())
        .help(title)
        .onHover { hovering in
            withAnimation(IslandMotion.hover) {
                isHovered = hovering
            }
        }
    }

    private var fillOpacity: CGFloat {
        if selectedSide == side { return 0.16 }
        return isHovered ? 0.10 : 0.06
    }
}

struct NBAStatHeaderRow: View {
    let teamTricode: String
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 0) {
            Text(teamTricode)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("MIN").frame(width: 42, alignment: .trailing)
            Text("PTS").frame(width: 34, alignment: .trailing)
            Text("REB").frame(width: 34, alignment: .trailing)
            Text("AST").frame(width: 34, alignment: .trailing)
            Text("+/-").frame(width: 38, alignment: .trailing)
        }
        .font(.system(size: 9.5, weight: .black, design: .rounded))
        .foregroundStyle(islandTextColor.opacity(0.42))
    }
}

struct NBAPlayerStatRow: View {
    let player: NBAPlayerLine
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 0) {
            Text(player.name)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            stat(player.minutes, width: 42)
            stat("\(player.points)", width: 34)
            stat("\(player.rebounds)", width: 34)
            stat("\(player.assists)", width: 34)
            stat(player.plusMinusText, width: 38)
        }
        .frame(height: 18)
        .foregroundStyle(islandTextColor.opacity(0.84))
    }

    private func stat(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .frame(width: width, alignment: .trailing)
    }
}
