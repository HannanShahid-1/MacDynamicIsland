import Foundation
import MacBookDynamicIslandCore

extension IslandStore {
    func startNBAScoresWatcher() {
        nbaScoresTimer?.invalidate()

        let timer = Timer(timeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNBAScoresFromTimer()
            }
        }
        timer.tolerance = 5.0

        nbaScoresTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    var nbaOptionsStatusText: String {
        guard nbaScoresEnabled else { return "Off until enabled" }

        switch nbaScoresStatus {
        case .disabled:
            return "Off until enabled"
        case .idle:
            return "Ready when NBA mode opens"
        case .loading:
            return "Checking NBA scores…"
        case .available:
            let count = nbaScoreboard?.games.count ?? 0
            return count == 1 ? "1 game today" : "\(count) games today"
        case .failed:
            return nbaScoreboard == nil ? "Scores unavailable" : "Using latest cached scores"
        }
    }

    var nbaGames: [NBAGameSummary] {
        nbaScoreboard?.games ?? []
    }

    var selectedNBAGame: NBAGameSummary? {
        guard let selectedNBAGameID else { return nil }
        return nbaGames.first { $0.id == selectedNBAGameID }
    }

    func enableNBAScores() {
        nbaScoresEnabled = true
        refreshNBAScoreboardIfVisible(force: true, manual: true)
    }

    func refreshNBAFromUserAction() {
        refreshNBAScoreboardIfVisible(force: true, manual: true)
        if let selectedNBAGameID {
            refreshNBABoxScore(for: selectedNBAGameID, force: true, manual: true)
        }
    }

    func selectNBAGame(_ game: NBAGameSummary) {
        if selectedNBAGameID == game.id {
            nbaBoxScoreTask?.cancel()
            nbaBoxScoreTask = nil
            selectedNBAGameID = nil
            nbaBoxScore = nil
            nbaBoxScoreStatus = .idle
            nbaBoxScoreSide = .away
            return
        }

        nbaBoxScoreTask?.cancel()
        nbaBoxScoreTask = nil
        selectedNBAGameID = game.id
        nbaBoxScoreSide = .away

        if let cached = nbaBoxScoreCache[game.id] {
            nbaBoxScore = cached
            nbaBoxScoreStatus = .available
        } else {
            nbaBoxScore = nil
            nbaBoxScoreStatus = .idle
        }

        refreshNBABoxScore(for: game.id, force: false, manual: false)
    }

    var isNBAModeVisible: Bool {
        isExpanded && (
            islandMode == .nba
                || (islandMode == .player
                    && layoutMode == .customTwoModes
                    && visibleHomeWidgets.contains(.nbaScores))
        )
    }

    private var isNBABoxScoreVisible: Bool {
        isExpanded && (
            islandMode == .nba
                || (islandMode == .player
                    && layoutMode == .customTwoModes
                    && visibleHomeWidgets == [.nbaScores])
        )
    }

    func handleNBAScoresEnabledChange() {
        guard nbaScoresEnabled else {
            clearNBAData()
            nbaScoresStatus = .disabled
            return
        }

        nbaScoresStatus = .idle
        refreshNBAScoreboardIfVisible(force: true, manual: false)
    }

    func clearNBAData() {
        nbaScoreboardTask?.cancel()
        nbaScoreboardTask = nil
        nbaBoxScoreTask?.cancel()
        nbaBoxScoreTask = nil
        nbaScoreboard = nil
        selectedNBAGameID = nil
        nbaBoxScore = nil
        nbaBoxScoreStatus = .idle
        lastNBAScoreboardRefreshDate = .distantPast
        lastNBABoxScoreRefreshDates.removeAll()
        nbaScoreboardFailureCount = 0
        nbaBoxScoreFailureCounts.removeAll()
        nbaBoxScoreCache.removeAll()
        nbaBoxScoreCacheKeys.removeAll()
    }

    private func refreshNBAScoresFromTimer() {
        guard !ambientRefreshesArePaused else { return }
        refreshNBAScoreboardIfVisible(force: false, manual: false)

        guard isNBABoxScoreVisible else { return }
        guard let selectedNBAGameID else { return }
        refreshNBABoxScore(for: selectedNBAGameID, force: false, manual: false)
    }

    func refreshNBAScoreboardIfVisible(force: Bool, manual: Bool) {
        guard NBARequestGate.canFetchScoreboard(
            isEnabled: nbaScoresEnabled,
            isNBAVisible: isNBAModeVisible,
            isManual: manual
        ) else {
            if !nbaScoresEnabled {
                nbaScoresStatus = .disabled
            }
            return
        }

        guard force || shouldRefreshNBAScoreboard else { return }
        guard nbaScoreboardTask == nil else { return }

        if nbaScoreboard == nil {
            nbaScoresStatus = .loading
        }

        let client = NBAClient(httpClient: LiveNBAHTTPClient.shared)
        nbaScoreboardTask = Task { [weak self] in
            do {
                let scoreboard = try await client.fetchScoreboard()
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard let self else { return }
                    self.handleNBAScoreboardSuccess(scoreboard)
                }
            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard let self else { return }
                    self.handleNBAScoreboardFailure()
                }
            }
        }
    }

    private var shouldRefreshNBAScoreboard: Bool {
        guard let interval = NBAScoresRefreshPolicy.scoreboardInterval(
            isEnabled: nbaScoresEnabled,
            isVisible: isNBAModeVisible,
            hasLiveGame: nbaScoreboard?.hasLiveGame ?? false,
            failureCount: nbaScoreboardFailureCount
        ) else {
            return false
        }

        return Date().timeIntervalSince(lastNBAScoreboardRefreshDate) >= interval
    }

    private func handleNBAScoreboardSuccess(_ scoreboard: NBAScoreboard) {
        nbaScoreboard = scoreboard
        nbaScoresStatus = .available
        lastNBAScoreboardRefreshDate = Date()
        nbaScoreboardFailureCount = 0
        nbaScoreboardTask = nil

        if let selectedNBAGameID,
           !scoreboard.games.contains(where: { $0.id == selectedNBAGameID }) {
            self.selectedNBAGameID = nil
            nbaBoxScore = nil
            nbaBoxScoreStatus = .idle
        }
    }

    private func handleNBAScoreboardFailure() {
        lastNBAScoreboardRefreshDate = Date()
        nbaScoreboardFailureCount += 1
        nbaScoresStatus = .failed("Scores unavailable")
        nbaScoreboardTask = nil
    }

    private func refreshNBABoxScore(for gameId: String, force: Bool, manual: Bool) {
        guard NBARequestGate.canFetchBoxScore(
            isEnabled: nbaScoresEnabled,
            isNBAVisible: isNBABoxScoreVisible,
            isManual: manual
        ) else {
            return
        }

        guard let game = nbaGames.first(where: { $0.id == gameId }) else { return }
        let cached = nbaBoxScoreCache[gameId]

        if game.status == .scheduled, !game.hasScore {
            if selectedNBAGameID == gameId, cached == nil {
                nbaBoxScoreStatus = .idle
            }
            return
        }

        if cached != nil, game.status.isFinal, !force {
            if selectedNBAGameID == gameId {
                nbaBoxScore = cached
                nbaBoxScoreStatus = .available
            }
            return
        }

        guard force || shouldRefreshNBABoxScore(for: game, cached: cached) else { return }
        guard nbaBoxScoreTask == nil else { return }

        if cached == nil {
            nbaBoxScoreStatus = .loading
        }

        let client = NBAClient(httpClient: LiveNBAHTTPClient.shared)
        nbaBoxScoreTask = Task { [weak self, gameId] in
            do {
                let boxScore = try await client.fetchBoxScore(gameId: gameId)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard let self else { return }
                    self.handleNBABoxScoreSuccess(boxScore)
                }
            } catch {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard let self else { return }
                    self.handleNBABoxScoreFailure(for: gameId)
                }
            }
        }
    }

    private func shouldRefreshNBABoxScore(for game: NBAGameSummary, cached: NBABoxScore?) -> Bool {
        guard let interval = NBAScoresRefreshPolicy.boxScoreInterval(
            isEnabled: nbaScoresEnabled,
            isVisible: isNBABoxScoreVisible,
            selectedGameIsLive: game.status.isLive,
            selectedGameIsFinal: game.status.isFinal,
            hasCachedFinal: cached != nil,
            failureCount: nbaBoxScoreFailureCounts[game.id] ?? 0
        ) else {
            return false
        }

        let lastRefreshDate = lastNBABoxScoreRefreshDates[game.id] ?? .distantPast
        return Date().timeIntervalSince(lastRefreshDate) >= interval
    }

    private func handleNBABoxScoreSuccess(_ boxScore: NBABoxScore) {
        cacheNBABoxScore(boxScore)
        nbaBoxScoreFailureCounts[boxScore.gameId] = 0
        lastNBABoxScoreRefreshDates[boxScore.gameId] = Date()
        nbaBoxScoreTask = nil

        guard selectedNBAGameID == boxScore.gameId else { return }
        nbaBoxScore = boxScore
        nbaBoxScoreStatus = .available
    }

    private func handleNBABoxScoreFailure(for gameId: String) {
        lastNBABoxScoreRefreshDates[gameId] = Date()
        nbaBoxScoreFailureCounts[gameId, default: 0] += 1
        nbaBoxScoreTask = nil

        guard selectedNBAGameID == gameId else { return }
        nbaBoxScoreStatus = .failed("Box score unavailable")
    }

    private func cacheNBABoxScore(_ boxScore: NBABoxScore) {
        nbaBoxScoreCache[boxScore.gameId] = boxScore
        nbaBoxScoreCacheKeys.removeAll { $0 == boxScore.gameId }
        nbaBoxScoreCacheKeys.append(boxScore.gameId)

        while nbaBoxScoreCacheKeys.count > 8 {
            let oldestKey = nbaBoxScoreCacheKeys.removeFirst()
            nbaBoxScoreCache.removeValue(forKey: oldestKey)
            nbaBoxScoreFailureCounts.removeValue(forKey: oldestKey)
            lastNBABoxScoreRefreshDates.removeValue(forKey: oldestKey)
        }
    }
}
