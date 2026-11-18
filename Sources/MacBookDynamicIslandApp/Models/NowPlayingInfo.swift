import AppKit

enum MediaPlaybackState {
    case unknown
    case stopped
    case paused
    case playing

    var isPlaying: Bool {
        self == .playing
    }

    var displayText: String {
        switch self {
        case .unknown:
            return "unknown"
        case .stopped:
            return "stopped"
        case .paused:
            return "paused"
        case .playing:
            return "playing"
        }
    }

    init(appleMusicState: String) {
        switch appleMusicState.lowercased() {
        case "playing":
            self = .playing
        case "paused":
            self = .paused
        case "stopped":
            self = .stopped
        default:
            self = .unknown
        }
    }
}

struct MediaControlAvailability: Equatable {
    var playPause = false
    var previous = false
    var next = false
}

/// Where the store currently gets its now-playing data.
enum NowPlayingSource {
    /// Waiting for the system-wide helper's first report.
    case starting
    /// macOS's system-wide Now Playing: Music, Spotify, browser tabs, and anything else.
    case system
    /// The helper is unavailable, so Apple Music is polled directly over AppleScript.
    case appleMusicFallback
}

enum NowPlayingAvailability {
    case available
    /// No app on the Mac currently has anything to show.
    case nothingPlaying
    /// Only used by the Apple Music fallback, when Music is not running.
    case musicNotOpen
    /// Only used by the Apple Music fallback, when Automation access was refused.
    case permissionDenied
}

struct NowPlayingInfo {
    var title: String?
    var artist: String?
    var album: String?
    var artwork: NSImage?
    var duration: TimeInterval?
    var position: TimeInterval?
    var sourceApp: String?
    /// Bundle identifier of the app that is playing. Nil for the Apple Music fallback.
    var sourceBundleID: String?
    var playbackState: MediaPlaybackState = .unknown
    var controls = MediaControlAvailability()
    var availability: NowPlayingAvailability = .musicNotOpen

    static let empty = NowPlayingInfo.nothingPlaying()

    static func nothingPlaying() -> NowPlayingInfo {
        NowPlayingInfo(
            playbackState: .stopped,
            availability: .nothingPlaying
        )
    }

    static func musicNotOpen() -> NowPlayingInfo {
        NowPlayingInfo(
            sourceApp: "Apple Music",
            playbackState: .stopped,
            availability: .musicNotOpen
        )
    }

    static func permissionNeeded() -> NowPlayingInfo {
        NowPlayingInfo(
            sourceApp: "Apple Music",
            playbackState: .unknown,
            availability: .permissionDenied
        )
    }

    var hasContent: Bool {
        availability == .available
            && playbackState != .stopped
            && (title?.isEmpty == false || artist?.isEmpty == false)
    }

    var canControl: Bool {
        hasContent && controls.playPause
    }

    var artworkLookupKey: String? {
        guard hasContent else { return nil }

        let pieces = [title, artist, album]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !pieces.isEmpty else { return nil }
        return pieces.joined(separator: "|").lowercased()
    }

    var artworkSearchTerms: [String] {
        guard hasContent else { return [] }

        let trackTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trackArtist = artist?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trackAlbum = album?.trimmingCharacters(in: .whitespacesAndNewlines)

        let searchTermPieces = [
            [trackTitle, trackArtist, trackAlbum],
            [trackTitle, trackArtist],
            [trackTitle, trackAlbum],
            [trackArtist, trackAlbum],
            [trackTitle]
        ]

        var searchTerms: [String] = []
        for pieces in searchTermPieces {
            let searchTerm = pieces
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            guard !searchTerm.isEmpty, !searchTerms.contains(searchTerm) else { continue }
            searchTerms.append(searchTerm)
        }

        return searchTerms
    }

    var displayTitle: String {
        switch availability {
        case .nothingPlaying:
            return "Nothing playing"
        case .musicNotOpen:
            return "Apple Music not open"
        case .permissionDenied:
            return "Music permission needed"
        case .available:
            break
        }

        if playbackState == .stopped {
            return "Nothing playing"
        }

        if hasContent, title?.isEmpty != false {
            return "Unknown Title"
        }

        guard let title, !title.isEmpty else { return "Nothing playing" }
        return title
    }

    var displayArtist: String {
        switch availability {
        case .nothingPlaying:
            return "Play music or a video in any app"
        case .musicNotOpen:
            return "Open Music manually to show playback"
        case .permissionDenied:
            return "Allow Automation access to Music"
        case .available:
            break
        }

        if playbackState == .stopped {
            return "Apple Music is stopped"
        }

        if hasContent, artist?.isEmpty != false {
            return "Unknown Artist"
        }

        guard let artist, !artist.isEmpty else { return "Unknown Artist" }
        return artist
    }

    var detailLine: String {
        switch availability {
        case .nothingPlaying:
            return "Music, Spotify, browsers"
        case .musicNotOpen:
            return "Apple Music"
        case .permissionDenied:
            return "Automation permission denied"
        case .available:
            break
        }

        if playbackState == .stopped {
            return "stopped"
        }

        var pieces = [playbackState.displayText]

        if let album, !album.isEmpty {
            pieces.append(album)
        } else if let sourceApp, !sourceApp.isEmpty {
            pieces.append(sourceApp)
        }

        return pieces.joined(separator: " · ")
    }

    var progressFraction: Double? {
        guard let position, let duration, duration > 0 else { return nil }
        return min(max(position / duration, 0), 1)
    }

    var positionText: String? {
        guard let position else { return nil }
        return Self.timeText(position)
    }

    var durationText: String? {
        guard let duration, duration > 0 else { return nil }
        return Self.timeText(duration)
    }

    private static func timeText(_ seconds: TimeInterval) -> String {
        let safeSeconds = max(0, Int(seconds.rounded()))
        let minutes = safeSeconds / 60
        let remainingSeconds = safeSeconds % 60
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }
}
