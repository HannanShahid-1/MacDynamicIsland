import AppKit
import MacBookDynamicIslandCore

extension IslandStore {
    // MARK: - Lifecycle

    func startNowPlayingWatcher() {
        nowPlayingTimer?.invalidate()
        nowPlayingSource = .starting

        systemNowPlayingMonitor.onEvent = { [weak self] event in
            self?.handleSystemNowPlayingEvent(event)
        }
        systemNowPlayingMonitor.start()

        // The timer only does work in the Apple Music fallback; system-wide
        // updates are pushed by the monitor.
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNowPlayingFromTimer()
            }
        }
        timer.tolerance = 0.35

        nowPlayingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - Controls

    func togglePlayPause() {
        guard nowPlaying.canControl else { return }
        sendMediaCommand(.togglePlayPause, appleMusic: .togglePlayPause, fallbackRefreshDelay: 180_000_000)
    }

    func playPreviousTrack() {
        guard nowPlaying.controls.previous, nowPlaying.hasContent else { return }
        sendMediaCommand(.previousTrack, appleMusic: .previousTrack, fallbackRefreshDelay: 220_000_000)
    }

    func playNextTrack() {
        guard nowPlaying.controls.next, nowPlaying.hasContent else { return }
        sendMediaCommand(.nextTrack, appleMusic: .nextTrack, fallbackRefreshDelay: 220_000_000)
    }

    private func sendMediaCommand(
        _ command: SystemMediaCommand,
        appleMusic appleMusicCommand: AppleMusicCommand,
        fallbackRefreshDelay: UInt64
    ) {
        guard nowPlayingSource == .system else {
            handleMusicCommandResult(AppleMusicNowPlayingProvider.shared.send(appleMusicCommand))
            refreshNowPlaying(afterNanoseconds: fallbackRefreshDelay)
            return
        }

        SystemMediaRemote.send(command)

        if command == .togglePlayPause {
            // Flip the button right away instead of waiting for the system to report
            // back; the snapshot that follows either confirms it or corrects it.
            let expectedState: MediaPlaybackState = nowPlaying.playbackState.isPlaying ? .paused : .playing
            optimisticPlaybackState = expectedState
            optimisticPlaybackDeadline = Date().addingTimeInterval(0.8)

            var updatedInfo = nowPlaying
            updatedInfo.playbackState = expectedState
            nowPlaying = updatedInfo
        }

        nowPlayingReconcileTask?.cancel()
        nowPlayingReconcileTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled, let self else { return }

            self.nowPlayingReconcileTask = nil
            self.reapplyLatestSystemSnapshot()
        }
    }

    // MARK: - System-wide now playing

    func handleSystemNowPlayingEvent(_ event: SystemNowPlayingMonitor.Event) {
        switch event {
        case .snapshot(let snapshot):
            nowPlayingSource = .system
            latestSystemSnapshot = snapshot
            applySystemNowPlaying(snapshot, force: false)
        case .unavailable:
            guard nowPlayingSource != .appleMusicFallback else { return }

            nowPlayingSource = .appleMusicFallback
            latestSystemSnapshot = nil
            systemTrackKey = nil
            systemArtwork = nil
            optimisticPlaybackState = nil
            refreshNowPlaying()
        }
    }

    private func reapplyLatestSystemSnapshot() {
        guard nowPlayingSource == .system, let latestSystemSnapshot else { return }
        applySystemNowPlaying(latestSystemSnapshot, force: true)
    }

    private func applySystemNowPlaying(_ snapshot: SystemNowPlayingSnapshot, force: Bool) {
        guard snapshot.hasMedia, snapshot.playbackState != .stopped else {
            systemTrackKey = nil
            systemArtwork = nil
            optimisticPlaybackState = nil
            cancelArtworkLookup()

            if nowPlaying.availability != .nothingPlaying {
                nowPlaying = .nothingPlaying()
            }
            return
        }

        let trackKey = snapshot.trackKey
        let didChangeTrack = trackKey != systemTrackKey
        var didChangeArtwork = false

        // Artwork only arrives when it changes, so keep the decoded image (and
        // its identity, which the artwork view animates on) until then.
        if let artworkData = snapshot.decodedArtwork, let artworkImage = NSImage(data: artworkData) {
            systemArtwork = artworkImage
            didChangeArtwork = true
        } else if didChangeTrack {
            didChangeArtwork = nowPlaying.artwork != nil
            systemArtwork = nil
        }
        systemTrackKey = trackKey

        var info = NowPlayingInfo(
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            artwork: systemArtwork ?? (didChangeTrack ? nil : nowPlaying.artwork),
            duration: snapshot.duration,
            position: snapshot.elapsed,
            sourceApp: NowPlayingSourceCatalog.name(
                forBundleID: snapshot.owningBundleID,
                reportedName: snapshot.appName
            ),
            sourceBundleID: snapshot.owningBundleID,
            playbackState: snapshot.playbackState == .playing ? .playing : .paused,
            controls: MediaControlAvailability(
                playPause: snapshot.canTogglePlayback,
                previous: snapshot.supports(.previousTrack),
                next: snapshot.supports(.nextTrack)
            ),
            availability: .available
        )

        if let optimisticPlaybackState {
            if Date() < optimisticPlaybackDeadline, !didChangeTrack, info.playbackState != optimisticPlaybackState {
                info.playbackState = optimisticPlaybackState
            } else {
                self.optimisticPlaybackState = nil
            }
        }

        if didChangeTrack, pendingArtworkLookupKey != info.artworkLookupKey {
            cancelArtworkLookup()
        }

        if info.artwork == nil, let cachedArtwork = cachedLookupArtwork(for: info) {
            info.artwork = cachedArtwork
            didChangeArtwork = true
        }

        let didChange = force
            || didChangeTrack
            || didChangeArtwork
            || nowPlaying.availability != .available
            || info.playbackState != nowPlaying.playbackState
            || info.controls != nowPlaying.controls
            || info.sourceBundleID != nowPlaying.sourceBundleID
            || info.duration != nowPlaying.duration

        if !didChange {
            // Only the playback position moved. Publishing redraws the island, so
            // do it once a second while the player is on screen and rarely otherwise.
            guard !ambientRefreshesArePaused else { return }

            let interval: TimeInterval = isExpanded && islandMode == .player ? 0.9 : 4.0
            guard Date().timeIntervalSince(lastSystemNowPlayingApplyDate) >= interval else { return }
        }

        lastSystemNowPlayingApplyDate = Date()
        nowPlaying = info
        resolveArtworkIfNeeded(for: info)
    }

    // MARK: - Apple Music fallback

    func refreshNowPlaying(afterNanoseconds delay: UInt64 = 0, onlyWhenPlayerExpanded: Bool = false) {
        if delay > 0 {
            deferredNowPlayingRefreshTask?.cancel()
            deferredNowPlayingRefreshTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: delay)
                defer { deferredNowPlayingRefreshTask = nil }
                guard !Task.isCancelled else { return }
                if onlyWhenPlayerExpanded {
                    guard isExpanded, islandMode == .player else { return }
                }
                refreshNowPlaying()
            }
            return
        }

        switch nowPlayingSource {
        case .starting:
            return
        case .system:
            // Nothing to fetch: show the newest pushed snapshot (and its position) now.
            reapplyLatestSystemSnapshot()
            return
        case .appleMusicFallback:
            break
        }

        lastNowPlayingRefreshDate = Date()

        var refreshedInfo = AppleMusicNowPlayingProvider.shared.fetchNowPlaying()
        let previousArtworkLookupKey = nowPlaying.artworkLookupKey
        let refreshedArtworkLookupKey = refreshedInfo.artworkLookupKey
        let didChangeTrack = previousArtworkLookupKey != refreshedArtworkLookupKey

        if didChangeTrack, pendingArtworkLookupKey != refreshedArtworkLookupKey {
            cancelArtworkLookup()
        }

        if refreshedInfo.artwork == nil, let cachedArtwork = cachedLookupArtwork(for: refreshedInfo) {
            refreshedInfo.artwork = cachedArtwork
        } else if didChangeTrack {
            refreshedInfo.artwork = nil
        }

        nowPlaying = refreshedInfo
        resolveArtworkIfNeeded(for: refreshedInfo)
    }

    private func refreshNowPlayingFromTimer() {
        guard nowPlayingSource == .appleMusicFallback else { return }
        guard !ambientRefreshesArePaused else { return }

        let refreshInterval: TimeInterval = isExpanded && islandMode == .player ? 1.0 : 4.0
        guard Date().timeIntervalSince(lastNowPlayingRefreshDate) >= refreshInterval else { return }

        refreshNowPlaying()
    }

    // MARK: - Artwork lookup

    /// Looks the track up in the iTunes catalog when a music app supplied no artwork.
    private func resolveArtworkIfNeeded(for info: NowPlayingInfo) {
        guard info.hasContent,
              NowPlayingSourceCatalog.isMusicApp(bundleID: info.sourceBundleID),
              info.artwork == nil,
              let artworkLookupKey = info.artworkLookupKey,
              !info.artworkSearchTerms.isEmpty,
              canRetryArtworkLookup(for: artworkLookupKey) else {
            if !info.hasContent || !NowPlayingSourceCatalog.isMusicApp(bundleID: info.sourceBundleID) {
                cancelArtworkLookup()
            }
            return
        }

        guard pendingArtworkLookupKey != artworkLookupKey else { return }

        artworkLookupTask?.cancel()
        pendingArtworkLookupKey = artworkLookupKey

        artworkLookupTask = Task { [weak self] in
            let artworkData = await AppleMusicArtworkLookup.fetchArtworkData(searchTerms: info.artworkSearchTerms)

            await MainActor.run {
                guard let self, self.pendingArtworkLookupKey == artworkLookupKey else { return }

                defer {
                    self.pendingArtworkLookupKey = nil
                    self.artworkLookupTask = nil
                }

                guard let artworkData,
                      let artworkImage = NSImage(data: artworkData) else {
                    self.artworkLookupMisses[artworkLookupKey] = Date()
                    return
                }

                self.cacheArtwork(artworkData, for: artworkLookupKey)
                self.artworkLookupMisses.removeValue(forKey: artworkLookupKey)

                guard self.nowPlaying.artworkLookupKey == artworkLookupKey,
                      self.nowPlaying.artwork == nil else {
                    return
                }

                var updatedInfo = self.nowPlaying
                updatedInfo.artwork = artworkImage
                self.nowPlaying = updatedInfo
            }
        }
    }

    private func cancelArtworkLookup() {
        artworkLookupTask?.cancel()
        artworkLookupTask = nil
        pendingArtworkLookupKey = nil
    }

    private func cachedLookupArtwork(for info: NowPlayingInfo) -> NSImage? {
        guard NowPlayingSourceCatalog.isMusicApp(bundleID: info.sourceBundleID),
              let artworkLookupKey = info.artworkLookupKey,
              let cachedArtworkData = artworkCache[artworkLookupKey] else {
            return nil
        }

        return NSImage(data: cachedArtworkData)
    }

    private func cacheArtwork(_ artworkData: Data, for artworkLookupKey: String) {
        artworkCache[artworkLookupKey] = artworkData
        artworkCacheKeys.removeAll { $0 == artworkLookupKey }
        artworkCacheKeys.append(artworkLookupKey)

        while artworkCacheKeys.count > 24 {
            let oldestKey = artworkCacheKeys.removeFirst()
            artworkCache.removeValue(forKey: oldestKey)
            artworkLookupMisses.removeValue(forKey: oldestKey)
        }
    }

    private func canRetryArtworkLookup(for artworkLookupKey: String) -> Bool {
        guard let lastMissDate = artworkLookupMisses[artworkLookupKey] else { return true }
        return Date().timeIntervalSince(lastMissDate) > Self.artworkLookupMissRetryInterval
    }

    private func handleMusicCommandResult(_ result: AppleMusicCommandResult) {
        switch result {
        case .sent, .failed:
            return
        case .musicNotOpen:
            nowPlaying = .musicNotOpen()
        case .permissionDenied:
            nowPlaying = .permissionNeeded()
        }
    }
}
