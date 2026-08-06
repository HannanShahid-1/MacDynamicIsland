import Foundation
#if canImport(Testing)
import Testing
@testable import MacBookDynamicIslandCore

@Suite("NBA data")
struct NBADataTests {
    @Test func scoreboardDecodesLiveFinalScheduledAndEmptyStates() throws {
        let scoreboard = try NBAScoreboard(data: Self.scoreboardData, updatedAt: Self.now)

        #expect(scoreboard.gameDate == "2026-05-10")
        #expect(scoreboard.games.count == 3)
        #expect(scoreboard.hasLiveGame)

        #expect(scoreboard.games[0].status == .live)
        #expect(scoreboard.games[0].displayStatus == "Q3 06:18")
        #expect(scoreboard.games[0].awayTeam.tricode == "NYK")
        #expect(scoreboard.games[0].homeTeam.score == 84)

        #expect(scoreboard.games[1].status == .final)
        #expect(scoreboard.games[1].displayStatus == "Final")
        #expect(scoreboard.games[1].seriesText == "OKC leads 3-0")

        #expect(scoreboard.games[2].status == .scheduled)
        #expect(!scoreboard.games[2].hasScore)

        let empty = try NBAScoreboard(data: Self.emptyScoreboardData, updatedAt: Self.now)
        #expect(empty.games.isEmpty)
        #expect(!empty.hasLiveGame)
    }

    @Test func boxScoreDecodesAndFormatsPlayerRows() throws {
        let boxScore = try NBABoxScore(data: Self.boxScoreData, updatedAt: Self.now)

        #expect(boxScore.gameId == "0042500203")
        #expect(boxScore.awayTeam.tricode == "DET")
        #expect(boxScore.homeTeam.tricode == "CLE")
        #expect(boxScore.awayTeam.players.count == 1)
        #expect(boxScore.homeTeam.players.count == 1)

        let player = try #require(boxScore.awayTeam.players.first)
        #expect(player.name == "Cade Cunningham")
        #expect(player.minutes == "38:22")
        #expect(player.points == 27)
        #expect(player.rebounds == 10)
        #expect(player.assists == 10)
        #expect(player.plusMinusText == "+7")
    }

    @Test func liveGameClockNormalizesNBADuration() {
        let game = NBAGameSummary(
            id: "0042500301",
            awayTeam: NBATeamSummary(city: "New York", name: "Knicks", tricode: "NYK", score: 8),
            homeTeam: NBATeamSummary(city: "Philadelphia", name: "76ers", tricode: "PHI", score: 4),
            status: .live,
            statusText: "Q1",
            period: 1,
            clock: "PT08M02.00S",
            gameTimeUTC: "2026-05-10T19:00:00Z",
            seriesText: "NYK leads 3-0",
            gameLabel: nil
        )

        #expect(game.displayStatus == "Q1 8:02")
    }

    @Test func boxScoreURLConstruction() {
        #expect(
            NBAEndpointBuilder.scoreboardURL.absoluteString
                == "https://nba-prod-us-east-1-mediaops-stats.s3.amazonaws.com/NBA/liveData/scoreboard/todaysScoreboard_00.json"
        )
        #expect(
            NBAEndpointBuilder.scoreboardURLs.map(\.absoluteString) == [
                "https://nba-prod-us-east-1-mediaops-stats.s3.amazonaws.com/NBA/liveData/scoreboard/todaysScoreboard_00.json",
                "https://cdn.nba.com/static/json/liveData/scoreboard/todaysScoreboard_00.json"
            ]
        )
        #expect(
            NBAEndpointBuilder.boxScoreURL(gameId: "0042500203")?.absoluteString
                == "https://nba-prod-us-east-1-mediaops-stats.s3.amazonaws.com/NBA/liveData/boxscore/boxscore_0042500203.json"
        )
        #expect(
            NBAEndpointBuilder.boxScoreURLs(gameId: "0042500203").map(\.absoluteString) == [
                "https://nba-prod-us-east-1-mediaops-stats.s3.amazonaws.com/NBA/liveData/boxscore/boxscore_0042500203.json",
                "https://cdn.nba.com/static/json/liveData/boxscore/boxscore_0042500203.json"
            ]
        )
        #expect(NBAEndpointBuilder.boxScoreURL(gameId: "../0042500203") == nil)
        #expect(NBAEndpointBuilder.boxScoreURL(gameId: "123") == nil)
        #expect(NBAEndpointBuilder.boxScoreURLs(gameId: "../0042500203") == [])
        #expect(NBAEndpointBuilder.boxScoreURLs(gameId: "123") == [])
    }

    @Test func refreshPolicyIntervals() {
        #expect(NBAScoresRefreshPolicy.scoreboardInterval(isEnabled: false, isVisible: true, hasLiveGame: true) == nil)
        #expect(NBAScoresRefreshPolicy.scoreboardInterval(isEnabled: true, isVisible: false, hasLiveGame: true) == nil)
        #expect(NBAScoresRefreshPolicy.scoreboardInterval(isEnabled: true, isVisible: true, hasLiveGame: true) == 60)
        #expect(NBAScoresRefreshPolicy.scoreboardInterval(isEnabled: true, isVisible: true, hasLiveGame: false) == 300)
        #expect(
            NBAScoresRefreshPolicy.boxScoreInterval(
                isEnabled: true,
                isVisible: true,
                selectedGameIsLive: true,
                selectedGameIsFinal: false,
                hasCachedFinal: false
            ) == 60
        )
        #expect(
            NBAScoresRefreshPolicy.boxScoreInterval(
                isEnabled: true,
                isVisible: true,
                selectedGameIsLive: false,
                selectedGameIsFinal: true,
                hasCachedFinal: true
            ) == nil
        )
    }

    @Test func failureBackoffCapsAtFifteenMinutes() {
        #expect(NBAScoresRefreshPolicy.failureBackoff(failureCount: 1) == 120)
        #expect(NBAScoresRefreshPolicy.failureBackoff(failureCount: 2) == 240)
        #expect(NBAScoresRefreshPolicy.failureBackoff(failureCount: 6) == 900)
        #expect(
            NBAScoresRefreshPolicy.scoreboardInterval(
                isEnabled: true,
                isVisible: true,
                hasLiveGame: true,
                failureCount: 3
            ) == 480
        )
    }

    @Test func disabledGatePreventsFakeClientRequest() async throws {
        let fake = FakeNBAHTTPClient()
        let client = NBAClient(httpClient: fake)

        if NBARequestGate.canFetchScoreboard(isEnabled: false, isNBAVisible: true, isManual: false) {
            _ = try await client.fetchScoreboard(updatedAt: Self.now)
        }

        #expect(fake.requestedURLs == [])
    }

    @Test func clientUsesPrimaryScoreboardURLWhenAvailable() async throws {
        let fake = FakeNBAHTTPClient()
        let client = NBAClient(httpClient: fake)

        _ = try await client.fetchScoreboard(updatedAt: Self.now)

        #expect(fake.requestedURLs == [NBAEndpointBuilder.scoreboardURLs[0]])
    }

    @Test func clientFallsBackAfterPrimaryScoreboardStatusFailure() async throws {
        let fake = FakeNBAHTTPClient(responses: [
            (statusCode: 403, data: Data()),
            (statusCode: 200, data: Self.scoreboardData)
        ])
        let client = NBAClient(httpClient: fake)

        let scoreboard = try await client.fetchScoreboard(updatedAt: Self.now)

        #expect(scoreboard.games.count == 3)
        #expect(fake.requestedURLs == NBAEndpointBuilder.scoreboardURLs)
    }

    @Test func clientSurfacesBadStatusWithoutDecoding() async throws {
        let fake = FakeNBAHTTPClient(statusCode: 429, data: Self.scoreboardData)
        let client = NBAClient(httpClient: fake)

        do {
            _ = try await client.fetchScoreboard(updatedAt: Self.now)
            Issue.record("Expected bad status")
        } catch let error as NBADataError {
            #expect(error == .badStatus(429))
        }
    }

    private static let now = Date(timeIntervalSince1970: 1_779_000_000)

    private static let emptyScoreboardData = """
    {
      "scoreboard": {
        "gameDate": "2026-05-10",
        "games": []
      }
    }
    """.data(using: .utf8)!

    fileprivate static let scoreboardData = """
    {
      "scoreboard": {
        "gameDate": "2026-05-10",
        "games": [
          {
            "gameId": "0042500301",
            "gameStatus": 2,
            "gameStatusText": "Q3",
            "period": 3,
            "gameClock": "06:18",
            "gameTimeUTC": "2026-05-10T19:00:00Z",
            "seriesText": "Series tied 1-1",
            "gameLabel": "East Conf. Semifinals",
            "homeTeam": {
              "teamCity": "Boston",
              "teamName": "Celtics",
              "teamTricode": "BOS",
              "score": 84
            },
            "awayTeam": {
              "teamCity": "New York",
              "teamName": "Knicks",
              "teamTricode": "NYK",
              "score": 81
            }
          },
          {
            "gameId": "0042500223",
            "gameStatus": 3,
            "gameStatusText": "Final",
            "period": 4,
            "gameClock": "",
            "gameTimeUTC": "2026-05-10T00:30:00Z",
            "seriesText": "OKC leads 3-0",
            "gameLabel": "West Conf. Semifinals",
            "homeTeam": {
              "teamCity": "Los Angeles",
              "teamName": "Lakers",
              "teamTricode": "LAL",
              "score": 108
            },
            "awayTeam": {
              "teamCity": "Oklahoma City",
              "teamName": "Thunder",
              "teamTricode": "OKC",
              "score": 131
            }
          },
          {
            "gameId": "0042500401",
            "gameStatus": 1,
            "gameStatusText": "8:30 pm ET",
            "period": 0,
            "gameClock": "",
            "gameTimeUTC": "2026-05-11T00:30:00Z",
            "seriesText": "",
            "gameLabel": "West Conf. Semifinals",
            "homeTeam": {
              "teamCity": "Minnesota",
              "teamName": "Timberwolves",
              "teamTricode": "MIN",
              "score": 0
            },
            "awayTeam": {
              "teamCity": "San Antonio",
              "teamName": "Spurs",
              "teamTricode": "SAS",
              "score": 0
            }
          }
        ]
      }
    }
    """.data(using: .utf8)!

    private static let boxScoreData = """
    {
      "game": {
        "gameId": "0042500203",
        "awayTeam": {
          "teamTricode": "DET",
          "score": 109,
          "players": [
            {
              "personId": 1630595,
              "name": "Cade Cunningham",
              "nameI": "C. Cunningham",
              "firstName": "Cade",
              "familyName": "Cunningham",
              "played": "1",
              "statistics": {
                "minutes": "PT38M22.00S",
                "minutesCalculated": "PT38M22.00S",
                "points": 27,
                "reboundsTotal": 10,
                "assists": 10,
                "plusMinusPoints": 7
              }
            },
            {
              "personId": 1630000,
              "name": "Bench Player",
              "nameI": "B. Player",
              "firstName": "Bench",
              "familyName": "Player",
              "played": "0",
              "statistics": {
                "minutes": "",
                "minutesCalculated": "",
                "points": 0,
                "reboundsTotal": 0,
                "assists": 0,
                "plusMinusPoints": 0
              }
            }
          ]
        },
        "homeTeam": {
          "teamTricode": "CLE",
          "score": 116,
          "players": [
            {
              "personId": 1628378,
              "name": "Donovan Mitchell",
              "nameI": "D. Mitchell",
              "firstName": "Donovan",
              "familyName": "Mitchell",
              "played": "1",
              "statistics": {
                "minutes": "41:09",
                "minutesCalculated": "PT41M09.00S",
                "points": 35,
                "reboundsTotal": 10,
                "assists": 4,
                "plusMinusPoints": -2
              }
            }
          ]
        }
      }
    }
    """.data(using: .utf8)!
}

private final class FakeNBAHTTPClient: NBAHTTPClient, @unchecked Sendable {
    private(set) var requestedURLs: [URL] = []
    private let responses: [(statusCode: Int, data: Data)]

    init(statusCode: Int = 200, data: Data = NBADataTests.scoreboardData) {
        self.responses = [(statusCode: statusCode, data: data)]
    }

    init(responses: [(statusCode: Int, data: Data)]) {
        self.responses = responses
    }

    func data(from url: URL) async throws -> (Data, HTTPURLResponse) {
        let index = requestedURLs.count
        requestedURLs.append(url)
        let responseSpec = responses[min(index, responses.count - 1)]
        let response = HTTPURLResponse(
            url: url,
            statusCode: responseSpec.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseSpec.data, response)
    }
}
#endif
