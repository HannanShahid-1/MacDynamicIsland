import Foundation

public enum NBAGameStatus: Equatable, Sendable {
    case scheduled
    case live
    case final
    case unknown(Int)

    public init(rawValue: Int) {
        switch rawValue {
        case 1:
            self = .scheduled
        case 2:
            self = .live
        case 3:
            self = .final
        default:
            self = .unknown(rawValue)
        }
    }

    public var isLive: Bool {
        self == .live
    }

    public var isFinal: Bool {
        self == .final
    }
}

public struct NBATeamSummary: Equatable, Sendable {
    public var city: String
    public var name: String
    public var tricode: String
    public var score: Int

    public init(city: String, name: String, tricode: String, score: Int) {
        self.city = city
        self.name = name
        self.tricode = tricode
        self.score = score
    }
}

public struct NBAGameSummary: Identifiable, Equatable, Sendable {
    public var id: String
    public var awayTeam: NBATeamSummary
    public var homeTeam: NBATeamSummary
    public var status: NBAGameStatus
    public var statusText: String
    public var period: Int
    public var clock: String
    public var gameTimeUTC: String
    public var seriesText: String?
    public var gameLabel: String?

    public init(
        id: String,
        awayTeam: NBATeamSummary,
        homeTeam: NBATeamSummary,
        status: NBAGameStatus,
        statusText: String,
        period: Int,
        clock: String,
        gameTimeUTC: String,
        seriesText: String?,
        gameLabel: String?
    ) {
        self.id = id
        self.awayTeam = awayTeam
        self.homeTeam = homeTeam
        self.status = status
        self.statusText = statusText
        self.period = period
        self.clock = clock
        self.gameTimeUTC = gameTimeUTC
        self.seriesText = seriesText?.nilIfBlank
        self.gameLabel = gameLabel?.nilIfBlank
    }

    public var hasScore: Bool {
        status != .scheduled || awayTeam.score > 0 || homeTeam.score > 0
    }

    public var displayStatus: String {
        switch status {
        case .live:
            let trimmedClock = clock.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedClock.isEmpty {
                return "Q\(period) \(trimmedClock.normalizedNBAGameClock ?? trimmedClock)"
            }
            return period > 0 ? "Q\(period)" : "Live"
        case .final:
            return statusText.nilIfBlank ?? "Final"
        case .scheduled:
            return statusText.nilIfBlank ?? "Scheduled"
        case .unknown:
            return statusText.nilIfBlank ?? "NBA"
        }
    }
}

public struct NBAScoreboard: Equatable, Sendable {
    public var gameDate: String
    public var games: [NBAGameSummary]
    public var updatedAt: Date

    public init(gameDate: String, games: [NBAGameSummary], updatedAt: Date) {
        self.gameDate = gameDate
        self.games = games
        self.updatedAt = updatedAt
    }

    public init(data: Data, updatedAt: Date = Date()) throws {
        let response = try JSONDecoder().decode(ScoreboardResponse.self, from: data)
        self.init(
            gameDate: response.scoreboard.gameDate,
            games: response.scoreboard.games.map(NBAGameSummary.init(raw:)),
            updatedAt: updatedAt
        )
    }

    public var hasLiveGame: Bool {
        games.contains { $0.status.isLive }
    }
}

public struct NBAPlayerLine: Identifiable, Equatable, Sendable {
    public var id: Int
    public var name: String
    public var minutes: String
    public var points: Int
    public var rebounds: Int
    public var assists: Int
    public var plusMinus: Int
    public var played: Bool

    public init(
        id: Int,
        name: String,
        minutes: String,
        points: Int,
        rebounds: Int,
        assists: Int,
        plusMinus: Int,
        played: Bool
    ) {
        self.id = id
        self.name = name
        self.minutes = minutes
        self.points = points
        self.rebounds = rebounds
        self.assists = assists
        self.plusMinus = plusMinus
        self.played = played
    }

    public var plusMinusText: String {
        plusMinus > 0 ? "+\(plusMinus)" : "\(plusMinus)"
    }
}

public struct NBABoxScoreTeam: Equatable, Sendable {
    public var tricode: String
    public var score: Int
    public var players: [NBAPlayerLine]

    public init(tricode: String, score: Int, players: [NBAPlayerLine]) {
        self.tricode = tricode
        self.score = score
        self.players = players
    }
}

public struct NBABoxScore: Equatable, Sendable {
    public var gameId: String
    public var awayTeam: NBABoxScoreTeam
    public var homeTeam: NBABoxScoreTeam
    public var updatedAt: Date

    public init(gameId: String, awayTeam: NBABoxScoreTeam, homeTeam: NBABoxScoreTeam, updatedAt: Date) {
        self.gameId = gameId
        self.awayTeam = awayTeam
        self.homeTeam = homeTeam
        self.updatedAt = updatedAt
    }

    public init(data: Data, updatedAt: Date = Date()) throws {
        let response = try JSONDecoder().decode(BoxScoreResponse.self, from: data)
        self.init(
            gameId: response.game.gameId,
            awayTeam: NBABoxScoreTeam(raw: response.game.awayTeam),
            homeTeam: NBABoxScoreTeam(raw: response.game.homeTeam),
            updatedAt: updatedAt
        )
    }
}

public enum NBAScoresStatus: Equatable, Sendable {
    case disabled
    case idle
    case loading
    case available
    case failed(String)
}

public enum NBAScoresRefreshPolicy {
    public static let liveInterval: TimeInterval = 60
    public static let settledInterval: TimeInterval = 5 * 60
    public static let minimumFailureBackoff: TimeInterval = 2 * 60
    public static let maximumFailureBackoff: TimeInterval = 15 * 60

    public static func scoreboardInterval(
        isEnabled: Bool,
        isVisible: Bool,
        hasLiveGame: Bool,
        failureCount: Int = 0
    ) -> TimeInterval? {
        guard isEnabled, isVisible else { return nil }
        if failureCount > 0 {
            return failureBackoff(failureCount: failureCount)
        }
        return hasLiveGame ? liveInterval : settledInterval
    }

    public static func boxScoreInterval(
        isEnabled: Bool,
        isVisible: Bool,
        selectedGameIsLive: Bool,
        selectedGameIsFinal: Bool,
        hasCachedFinal: Bool,
        failureCount: Int = 0
    ) -> TimeInterval? {
        guard isEnabled, isVisible else { return nil }
        if failureCount > 0 {
            return failureBackoff(failureCount: failureCount)
        }
        if selectedGameIsFinal, hasCachedFinal {
            return nil
        }
        return selectedGameIsLive ? liveInterval : settledInterval
    }

    public static func failureBackoff(failureCount: Int) -> TimeInterval {
        guard failureCount > 0 else { return 0 }
        let multiplier = pow(2.0, Double(max(0, failureCount - 1)))
        return min(maximumFailureBackoff, minimumFailureBackoff * multiplier)
    }
}

public enum NBARequestGate {
    public static func canFetchScoreboard(isEnabled: Bool, isNBAVisible: Bool, isManual: Bool) -> Bool {
        isEnabled && (isNBAVisible || isManual)
    }

    public static func canFetchBoxScore(isEnabled: Bool, isNBAVisible: Bool, isManual: Bool) -> Bool {
        isEnabled && (isNBAVisible || isManual)
    }
}

public struct NBAEndpointBuilder {
    private static let originBaseURL = "https://nba-prod-us-east-1-mediaops-stats.s3.amazonaws.com/NBA/liveData"
    private static let cdnBaseURL = "https://cdn.nba.com/static/json/liveData"

    public static let scoreboardURLs = urls(for: "scoreboard/todaysScoreboard_00.json")
    public static let scoreboardURL = scoreboardURLs[0]

    public static func boxScoreURL(gameId: String) -> URL? {
        boxScoreURLs(gameId: gameId).first
    }

    public static func boxScoreURLs(gameId: String) -> [URL] {
        guard gameId.range(of: #"^\d{10}$"#, options: .regularExpression) != nil else {
            return []
        }

        return urls(for: "boxscore/boxscore_\(gameId).json")
    }

    private static func urls(for path: String) -> [URL] {
        [
            URL(string: "\(originBaseURL)/\(path)")!,
            URL(string: "\(cdnBaseURL)/\(path)")!
        ]
    }
}

public protocol NBAHTTPClient: Sendable {
    func data(from url: URL) async throws -> (Data, HTTPURLResponse)
}

public enum NBADataError: Error, Equatable {
    case invalidURL
    case badStatus(Int)
    case emptyResponse
}

public struct NBAClient: Sendable {
    private let httpClient: NBAHTTPClient

    public init(httpClient: NBAHTTPClient) {
        self.httpClient = httpClient
    }

    public func fetchScoreboard(updatedAt: Date = Date()) async throws -> NBAScoreboard {
        let data = try await firstValidResponse(from: NBAEndpointBuilder.scoreboardURLs)
        return try NBAScoreboard(data: data, updatedAt: updatedAt)
    }

    public func fetchBoxScore(gameId: String, updatedAt: Date = Date()) async throws -> NBABoxScore {
        let urls = NBAEndpointBuilder.boxScoreURLs(gameId: gameId)
        guard !urls.isEmpty else {
            throw NBADataError.invalidURL
        }

        let data = try await firstValidResponse(from: urls)
        return try NBABoxScore(data: data, updatedAt: updatedAt)
    }

    private func firstValidResponse(from urls: [URL]) async throws -> Data {
        var lastError: Error = NBADataError.invalidURL

        for url in urls {
            do {
                let (data, response) = try await httpClient.data(from: url)
                try Self.validate(data: data, response: response)
                return data
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    private static func validate(data: Data, response: HTTPURLResponse) throws {
        guard (200..<300).contains(response.statusCode) else {
            throw NBADataError.badStatus(response.statusCode)
        }
        guard !data.isEmpty else {
            throw NBADataError.emptyResponse
        }
    }
}

private extension NBAGameSummary {
    init(raw: ScoreboardGame) {
        self.init(
            id: raw.gameId,
            awayTeam: NBATeamSummary(raw: raw.awayTeam),
            homeTeam: NBATeamSummary(raw: raw.homeTeam),
            status: NBAGameStatus(rawValue: raw.gameStatus),
            statusText: raw.gameStatusText,
            period: raw.period,
            clock: raw.gameClock,
            gameTimeUTC: raw.gameTimeUTC,
            seriesText: raw.seriesText,
            gameLabel: raw.gameLabel
        )
    }
}

private extension NBATeamSummary {
    init(raw: ScoreboardTeam) {
        self.init(
            city: raw.teamCity,
            name: raw.teamName,
            tricode: raw.teamTricode,
            score: raw.score
        )
    }
}

private extension NBABoxScoreTeam {
    init(raw: BoxScoreTeam) {
        self.init(
            tricode: raw.teamTricode,
            score: raw.score,
            players: raw.players
                .map(NBAPlayerLine.init(raw:))
                .filter(\.played)
        )
    }
}

private extension NBAPlayerLine {
    init(raw: BoxScorePlayer) {
        self.init(
            id: raw.personId,
            name: raw.name?.nilIfBlank ?? raw.nameI?.nilIfBlank ?? "\(raw.firstName ?? "") \(raw.familyName ?? "")".trimmingCharacters(in: .whitespacesAndNewlines),
            minutes: raw.statistics.displayMinutes,
            points: raw.statistics.points ?? 0,
            rebounds: raw.statistics.reboundsTotal ?? 0,
            assists: raw.statistics.assists ?? 0,
            plusMinus: raw.statistics.plusMinusPoints ?? 0,
            played: raw.played == "1" || raw.played?.lowercased() == "true"
        )
    }
}

private extension BoxScorePlayerStatistics {
    var displayMinutes: String {
        minutes?.normalizedNBAMinutes ?? minutesCalculated?.normalizedNBAMinutes ?? "--"
    }
}

private struct ScoreboardResponse: Decodable {
    var scoreboard: ScoreboardPayload
}

private struct ScoreboardPayload: Decodable {
    var gameDate: String
    var games: [ScoreboardGame]
}

private struct ScoreboardGame: Decodable {
    var gameId: String
    var gameStatus: Int
    var gameStatusText: String
    var period: Int
    var gameClock: String
    var gameTimeUTC: String
    var seriesText: String?
    var gameLabel: String?
    var homeTeam: ScoreboardTeam
    var awayTeam: ScoreboardTeam
}

private struct ScoreboardTeam: Decodable {
    var teamName: String
    var teamCity: String
    var teamTricode: String
    var score: Int
}

private struct BoxScoreResponse: Decodable {
    var game: BoxScoreGame
}

private struct BoxScoreGame: Decodable {
    var gameId: String
    var homeTeam: BoxScoreTeam
    var awayTeam: BoxScoreTeam
}

private struct BoxScoreTeam: Decodable {
    var teamTricode: String
    var score: Int
    var players: [BoxScorePlayer]
}

private struct BoxScorePlayer: Decodable {
    var personId: Int
    var name: String?
    var nameI: String?
    var firstName: String?
    var familyName: String?
    var played: String?
    var statistics: BoxScorePlayerStatistics
}

private struct BoxScorePlayerStatistics: Decodable {
    var minutes: String?
    var minutesCalculated: String?
    var points: Int?
    var reboundsTotal: Int?
    var assists: Int?
    var plusMinusPoints: Int?
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalizedNBAMinutes: String? {
        normalizedNBAGameClock
    }

    var normalizedNBAGameClock: String? {
        guard let trimmed = nilIfBlank else { return nil }
        return Self.formatNBADuration(trimmed) ?? trimmed
    }

    private static func formatNBADuration(_ value: String) -> String? {
        let uppercased = value.uppercased()
        guard uppercased.hasPrefix("PT") else { return nil }

        let body = uppercased.dropFirst(2)
        guard let minuteMarker = body.firstIndex(of: "M") else { return nil }

        var minuteText = body[..<minuteMarker]
        var totalMinutes = 0

        if let hourMarker = minuteText.firstIndex(of: "H") {
            guard let hours = Int(minuteText[..<hourMarker]) else { return nil }
            totalMinutes += hours * 60
            minuteText = minuteText[minuteText.index(after: hourMarker)...]
        }

        guard let minutes = Int(minuteText) else { return nil }
        totalMinutes += minutes

        let secondsText = body[body.index(after: minuteMarker)...].dropLast()
        guard let secondsValue = Double(secondsText) else { return nil }

        return String(format: "%d:%02d", totalMinutes, Int(secondsValue.rounded(.down)))
    }
}
