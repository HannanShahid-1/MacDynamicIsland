import Foundation

import Testing
@testable import MacBookDynamicIslandCore

@Suite("System now playing")
struct SystemNowPlayingTests {
    @Test func decodesBrowserVideoWithoutAlbumOrArtwork() throws {
        let line = #"{"active":true,"bundleID":"org.mozilla.firefox","parentBundleID":null,"appName":"Firefox","playbackState":2,"commands":[24,2,1,0],"title":"A video","artist":"A channel","album":null,"duration":213.401,"elapsed":55.62}"#
        let snapshot = try JSONDecoder().decode(SystemNowPlayingSnapshot.self, from: Data(line.utf8))

        #expect(snapshot.hasMedia)
        #expect(snapshot.owningBundleID == "org.mozilla.firefox")
        #expect(snapshot.playbackState == .paused)
        #expect(snapshot.title == "A video")
        #expect(snapshot.album == nil)
        #expect(snapshot.duration == 213.401)
        #expect(snapshot.canTogglePlayback)
        #expect(!snapshot.supports(.nextTrack))
        #expect(!snapshot.supports(.previousTrack))
        #expect(snapshot.decodedArtwork == nil)
    }

    @Test func decodesIdleAndErrorMessages() throws {
        let idle = try JSONDecoder().decode(SystemNowPlayingSnapshot.self, from: Data(#"{"active":false}"#.utf8))
        #expect(!idle.active)
        #expect(!idle.hasMedia)
        #expect(idle.commands.isEmpty)
        #expect(idle.error == nil)

        let failure = try JSONDecoder().decode(SystemNowPlayingSnapshot.self, from: Data(#"{"error":"boom"}"#.utf8))
        #expect(!failure.active)
        #expect(failure.error == "boom")
    }

    @Test func safariHelperProcessResolvesToSafari() {
        let snapshot = SystemNowPlayingSnapshot(
            active: true,
            bundleID: "com.apple.WebKit.GPU",
            parentBundleID: "com.apple.Safari",
            title: "Video"
        )

        #expect(snapshot.owningBundleID == "com.apple.Safari")
    }

    @Test func playbackStateMapping() {
        #expect(SystemPlaybackState(rawValue: 1) == .playing)
        #expect(SystemPlaybackState(rawValue: 2) == .paused)
        #expect(SystemPlaybackState(rawValue: 3) == .stopped)
        #expect(SystemPlaybackState(rawValue: 4) == .paused)
        #expect(SystemPlaybackState(rawValue: 0) == .unknown)
        #expect(SystemPlaybackState(rawValue: nil) == .unknown)
    }

    @Test func commandSupport() {
        let music = SystemNowPlayingSnapshot(active: true, commands: [0, 1, 2, 4, 5], title: "Song")
        #expect(music.canTogglePlayback)
        #expect(music.supports(.nextTrack))
        #expect(music.supports(.previousTrack))

        let silent = SystemNowPlayingSnapshot(active: true, commands: [], title: "Song")
        #expect(silent.canTogglePlayback)
        #expect(!silent.supports(.nextTrack))

        let seekOnly = SystemNowPlayingSnapshot(active: true, commands: [24], title: "Song")
        #expect(!seekOnly.canTogglePlayback)
    }

    @Test func trackKeyChangesWithTrackButNotPosition() {
        var first = SystemNowPlayingSnapshot(
            active: true, bundleID: "com.spotify.client", title: "Song", artist: "Artist", album: "Album", elapsed: 1
        )
        let key = first.trackKey
        first.elapsed = 30
        first.playbackStateCode = 2
        #expect(first.trackKey == key)

        first.title = "Other song"
        #expect(first.trackKey != key)
    }

    @Test func artworkDecodesFromBase64() {
        let bytes = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let snapshot = SystemNowPlayingSnapshot(active: true, title: "Song", artwork: bytes.base64EncodedString())
        #expect(snapshot.decodedArtwork == bytes)
    }

    @Test func parserReassemblesLinesSplitAcrossChunks() {
        var parser = SystemNowPlayingStreamParser()
        let stream = Data((#"{"active":false}"# + "\n" + #"{"active":true,"bundleID":"com.spotify.client","title":"Song"}"# + "\n").utf8)

        var snapshots: [SystemNowPlayingSnapshot] = []
        for byte in stream {
            snapshots += parser.append(Data([byte]))
        }

        #expect(snapshots.count == 2)
        #expect(snapshots.first?.active == false)
        #expect(snapshots.last?.title == "Song")
    }

    @Test func parserSkipsGarbageAndKeepsGoing() {
        var parser = SystemNowPlayingStreamParser()
        let snapshots = parser.append(Data("not json\n\n{\"active\":true,\"title\":\"Song\"}\n{\"active\":tr".utf8))

        #expect(snapshots.count == 1)
        #expect(snapshots.first?.title == "Song")

        let rest = parser.append(Data("ue,\"title\":\"Next\"}\n".utf8))
        #expect(rest.first?.title == "Next")
    }
}
