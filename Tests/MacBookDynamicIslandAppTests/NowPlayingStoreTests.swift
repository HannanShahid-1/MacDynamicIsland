import AppKit

import MacBookDynamicIslandCore
import Testing
@testable import MacBookDynamicIslandApp

/// Feeds system Now Playing snapshots into the store the way the helper monitor
/// does. Uses made-up bundle identifiers so nothing depends on installed apps,
/// and never sends playback commands (those would reach whatever is really playing).
@MainActor
@Suite("Now playing store")
struct NowPlayingStoreTests {
    private func playingVideo(elapsed: Double = 10, artwork: String? = nil) -> SystemNowPlayingSnapshot {
        SystemNowPlayingSnapshot(
            active: true,
            bundleID: "com.example.browser",
            appName: "Example Browser",
            playbackStateCode: 1,
            commands: [0, 1, 2],
            title: "A video",
            artist: "A channel",
            duration: 200,
            elapsed: elapsed,
            artworkID: artwork == nil ? nil : "art:1",
            artwork: artwork
        )
    }

    private func sampleArtwork() -> String {
        let image = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
            NSColor.systemPink.setFill()
            rect.fill()
            return true
        }
        return image.tiffRepresentation!.base64EncodedString()
    }

    @Test func browserVideoBecomesControllableNowPlaying() {
        let store = IslandStore()
        store.handleSystemNowPlayingEvent(.snapshot(playingVideo()))

        let info = store.nowPlaying
        #expect(store.nowPlayingSource == .system)
        #expect(info.hasContent)
        #expect(info.canControl)
        #expect(info.displayTitle == "A video")
        #expect(info.displayArtist == "A channel")
        #expect(info.sourceApp == "Example Browser")
        #expect(info.detailLine == "playing · Example Browser")
        #expect(info.playbackState == .playing)
        #expect(info.progressFraction == 0.05)
        #expect(!info.controls.next)
        #expect(!info.controls.previous)
    }

    @Test func pauseIsShownImmediately() {
        let store = IslandStore()
        store.handleSystemNowPlayingEvent(.snapshot(playingVideo()))

        var paused = playingVideo(elapsed: 12)
        paused.playbackStateCode = 2
        store.handleSystemNowPlayingEvent(.snapshot(paused))

        #expect(store.nowPlaying.playbackState == .paused)
        #expect(store.nowPlaying.position == 12)
        #expect(store.nowPlaying.hasContent)
    }

    @Test func nothingPlayingWhenNoAppOwnsNowPlaying() {
        let store = IslandStore()
        store.handleSystemNowPlayingEvent(.snapshot(playingVideo()))
        store.handleSystemNowPlayingEvent(.snapshot(SystemNowPlayingSnapshot(active: false)))

        #expect(!store.nowPlaying.hasContent)
        #expect(store.nowPlaying.availability == .nothingPlaying)
        #expect(store.nowPlaying.displayTitle == "Nothing playing")
    }

    @Test func artworkIsKeptUntilTheTrackChanges() {
        let store = IslandStore()
        store.handleSystemNowPlayingEvent(.snapshot(playingVideo(artwork: sampleArtwork())))
        let artwork = store.nowPlaying.artwork
        #expect(artwork != nil)

        // Later snapshots for the same item omit the image data.
        var paused = playingVideo(elapsed: 11)
        paused.playbackStateCode = 2
        paused.artworkID = "art:1"
        store.handleSystemNowPlayingEvent(.snapshot(paused))
        #expect(store.nowPlaying.artwork === artwork)

        var next = playingVideo(elapsed: 0)
        next.title = "Another video"
        store.handleSystemNowPlayingEvent(.snapshot(next))
        #expect(store.nowPlaying.displayTitle == "Another video")
        #expect(store.nowPlaying.artwork == nil)
    }

    @Test func positionOnlyUpdatesAreThrottledWhileCollapsed() {
        let store = IslandStore()
        store.handleSystemNowPlayingEvent(.snapshot(playingVideo(elapsed: 10)))
        store.handleSystemNowPlayingEvent(.snapshot(playingVideo(elapsed: 11)))

        #expect(!store.isExpanded)
        #expect(store.nowPlaying.position == 10)
    }

    @Test func safariHelperIsAttributedToSafari() {
        let store = IslandStore()
        var snapshot = playingVideo()
        snapshot.bundleID = "com.apple.WebKit.GPU"
        snapshot.parentBundleID = "com.apple.Safari"
        snapshot.appName = nil
        store.handleSystemNowPlayingEvent(.snapshot(snapshot))

        #expect(store.nowPlaying.sourceBundleID == "com.apple.Safari")
        #expect(store.nowPlaying.sourceApp == "Safari")
    }
}
