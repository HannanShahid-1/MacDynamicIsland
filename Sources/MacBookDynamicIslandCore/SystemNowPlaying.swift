import Foundation

/// Remote-control commands understood by macOS's system-wide Now Playing service.
/// The raw values are the service's own command identifiers.
public enum SystemMediaCommand: Int, Sendable {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case stop = 3
    case nextTrack = 4
    case previousTrack = 5
}

public enum SystemPlaybackState: Equatable, Sendable {
    case playing
    case paused
    case stopped
    case unknown

    /// Maps the Now Playing service's numeric playback state.
    public init(rawValue: Int?) {
        switch rawValue {
        case 1:
            self = .playing
        case 2, 4, 5:
            // Paused, interrupted, and seeking all show as "not currently advancing".
            self = .paused
        case 3:
            self = .stopped
        default:
            self = .unknown
        }
    }
}

/// One line of output from the Now Playing helper: whatever app currently owns
/// the system's Now Playing slot (Music, Spotify, a browser tab, ...).
public struct SystemNowPlayingSnapshot: Decodable, Equatable, Sendable {
    public var active: Bool
    public var bundleID: String?
    public var parentBundleID: String?
    public var appName: String?
    public var playbackStateCode: Int?
    public var commands: [Int]
    public var title: String?
    public var artist: String?
    public var album: String?
    public var duration: Double?
    public var elapsed: Double?
    public var artworkID: String?
    /// Base64 image data. Only present on the first snapshot after the artwork changes.
    public var artwork: String?
    /// Set when the helper could not start; no other field is meaningful then.
    public var error: String?

    enum CodingKeys: String, CodingKey {
        case active, bundleID, parentBundleID, appName
        case playbackStateCode = "playbackState"
        case commands, title, artist, album, duration, elapsed, artworkID, artwork, error
    }

    public init(
        active: Bool,
        bundleID: String? = nil,
        parentBundleID: String? = nil,
        appName: String? = nil,
        playbackStateCode: Int? = nil,
        commands: [Int] = [],
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        duration: Double? = nil,
        elapsed: Double? = nil,
        artworkID: String? = nil,
        artwork: String? = nil,
        error: String? = nil
    ) {
        self.active = active
        self.bundleID = bundleID
        self.parentBundleID = parentBundleID
        self.appName = appName
        self.playbackStateCode = playbackStateCode
        self.commands = commands
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsed = elapsed
        self.artworkID = artworkID
        self.artwork = artwork
        self.error = error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? false
        bundleID = try container.decodeIfPresent(String.self, forKey: .bundleID)
        parentBundleID = try container.decodeIfPresent(String.self, forKey: .parentBundleID)
        appName = try container.decodeIfPresent(String.self, forKey: .appName)
        playbackStateCode = try container.decodeIfPresent(Int.self, forKey: .playbackStateCode)
        commands = try container.decodeIfPresent([Int].self, forKey: .commands) ?? []
        title = try container.decodeIfPresent(String.self, forKey: .title)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        elapsed = try container.decodeIfPresent(Double.self, forKey: .elapsed)
        artworkID = try container.decodeIfPresent(String.self, forKey: .artworkID)
        artwork = try container.decodeIfPresent(String.self, forKey: .artwork)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }

    public var playbackState: SystemPlaybackState {
        SystemPlaybackState(rawValue: playbackStateCode)
    }

    /// True when there is something worth showing: an app owns Now Playing and named its media.
    public var hasMedia: Bool {
        active && (title != nil || artist != nil)
    }

    /// The app the user thinks of as the source. Safari plays media in a helper
    /// process (`com.apple.WebKit.GPU`) and reports itself as that helper's parent.
    public var owningBundleID: String? {
        parentBundleID ?? bundleID
    }

    /// Identifies the current item, so artwork can be carried across position-only updates.
    public var trackKey: String {
        [owningBundleID, title, artist, album]
            .map { $0 ?? "" }
            .joined(separator: "\u{1F}")
    }

    public var decodedArtwork: Data? {
        guard let artwork, !artwork.isEmpty else { return nil }
        return Data(base64Encoded: artwork)
    }

    public var canTogglePlayback: Bool {
        // Some apps publish no command list at all but still honor play/pause.
        commands.isEmpty
            || supports(.togglePlayPause)
            || supports(.play)
            || supports(.pause)
    }

    public func supports(_ command: SystemMediaCommand) -> Bool {
        commands.contains(command.rawValue)
    }
}

/// Turns the helper's stdout byte stream into snapshots, one JSON object per line.
/// Chunks can split a line anywhere (artwork lines are large), so bytes are buffered.
public struct SystemNowPlayingStreamParser {
    private var buffer = Data()
    private let decoder = JSONDecoder()

    public init() {}

    public mutating func append(_ chunk: Data) -> [SystemNowPlayingSnapshot] {
        buffer.append(chunk)

        var snapshots: [SystemNowPlayingSnapshot] = []
        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer[buffer.startIndex..<newlineIndex]
            buffer = Data(buffer[buffer.index(after: newlineIndex)...])

            guard !line.isEmpty,
                  let snapshot = try? decoder.decode(SystemNowPlayingSnapshot.self, from: line) else {
                continue
            }
            snapshots.append(snapshot)
        }

        return snapshots
    }
}
