import AppKit
import CoreServices

enum AppleMusicCommand {
    case togglePlayPause
    case nextTrack
    case previousTrack

    var appleScriptCommand: String {
        switch self {
        case .togglePlayPause:
            return "playpause"
        case .nextTrack:
            return "next track"
        case .previousTrack:
            return "previous track"
        }
    }
}

enum AppleMusicCommandResult {
    case sent
    case musicNotOpen
    case permissionDenied
    case failed
}

enum AppleMusicScriptError: Error {
    case permissionDenied
    case applicationNotRunning
    case failed
}

@MainActor
final class AppleMusicNowPlayingProvider {
    static let shared = AppleMusicNowPlayingProvider()

    private let musicBundleIdentifier = "com.apple.Music"

    private init() {}

    func fetchNowPlaying() -> NowPlayingInfo {
        guard isMusicRunning else { return .musicNotOpen() }

        switch execute(Self.nowPlayingScript) {
        case .success(let descriptor):
            return Self.nowPlayingInfo(from: descriptor)
        case .failure(.permissionDenied):
            return .permissionNeeded()
        case .failure(.applicationNotRunning):
            return .musicNotOpen()
        case .failure(.failed):
            return NowPlayingInfo(
                sourceApp: "Apple Music",
                playbackState: .unknown,
                availability: .available
            )
        }
    }

    func send(_ command: AppleMusicCommand) -> AppleMusicCommandResult {
        guard isMusicRunning else { return .musicNotOpen }

        let source = """
        tell application id "com.apple.Music"
            \(command.appleScriptCommand)
        end tell
        """

        switch execute(source) {
        case .success:
            return .sent
        case .failure(.permissionDenied):
            return .permissionDenied
        case .failure(.applicationNotRunning):
            return .musicNotOpen
        case .failure(.failed):
            return .failed
        }
    }

    private var isMusicRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { application in
            application.bundleIdentifier == musicBundleIdentifier
        }
    }

    private func execute(_ source: String) -> Result<NSAppleEventDescriptor, AppleMusicScriptError> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(.failed)
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            return .failure(Self.scriptError(from: errorInfo))
        }

        return .success(descriptor)
    }

    private static func nowPlayingInfo(from descriptor: NSAppleEventDescriptor) -> NowPlayingInfo {
        let playbackState = MediaPlaybackState(
            appleMusicState: listString(in: descriptor, at: 1) ?? "stopped"
        )
        let canControl = playbackState == .playing || playbackState == .paused

        return NowPlayingInfo(
            title: listString(in: descriptor, at: 2),
            artist: listString(in: descriptor, at: 3),
            album: listString(in: descriptor, at: 4),
            artwork: listImage(in: descriptor, at: 7),
            duration: listTimeInterval(in: descriptor, at: 5),
            position: listTimeInterval(in: descriptor, at: 6),
            sourceApp: "Apple Music",
            playbackState: playbackState,
            controls: MediaControlAvailability(
                playPause: canControl,
                previous: canControl,
                next: canControl
            ),
            availability: .available
        )
    }

    private static func listString(in descriptor: NSAppleEventDescriptor, at index: Int) -> String? {
        guard let value = descriptor.atIndex(index)?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }

    private static func listTimeInterval(in descriptor: NSAppleEventDescriptor, at index: Int) -> TimeInterval? {
        guard let value = listString(in: descriptor, at: index) else { return nil }
        return TimeInterval(value.replacingOccurrences(of: ",", with: "."))
    }

    private static func listImage(in descriptor: NSAppleEventDescriptor, at index: Int) -> NSImage? {
        guard let artworkDescriptor = descriptor.atIndex(index) else { return nil }
        return image(from: artworkDescriptor)
    }

    private static func image(from descriptor: NSAppleEventDescriptor) -> NSImage? {
        if let image = image(from: descriptor.data) {
            return image
        }

        for descriptorType in artworkDescriptorTypes where descriptorType != descriptor.descriptorType {
            if let coerced = descriptor.coerce(toDescriptorType: descriptorType),
               let image = image(from: coerced.data) {
                return image
            }
        }

        guard let stringValue = descriptor.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !stringValue.isEmpty else {
            return nil
        }

        if let image = image(fromAppleEventDataLiteral: stringValue) {
            return image
        }

        return image(fromLocalArtworkReference: stringValue)
    }

    private static func image(from data: Data) -> NSImage? {
        guard !data.isEmpty else { return nil }
        return NSImage(data: data)
    }

    private static func image(fromAppleEventDataLiteral string: String) -> NSImage? {
        guard string.hasPrefix("«data "),
              string.hasSuffix("»"),
              let metadataEnd = string.firstIndex(of: " ") else {
            return nil
        }

        let hexStart = string.index(after: metadataEnd)
        let hexEnd = string.index(before: string.endIndex)
        guard let payloadStart = string.index(hexStart, offsetBy: 4, limitedBy: hexEnd) else {
            return nil
        }

        let hexString = string[payloadStart..<hexEnd].filter { !$0.isWhitespace }
        guard hexString.count >= 2, hexString.count.isMultiple(of: 2) else {
            return nil
        }

        var bytes = [UInt8]()
        bytes.reserveCapacity(hexString.count / 2)

        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = nextIndex
        }

        return image(from: Data(bytes))
    }

    private static func image(fromLocalArtworkReference string: String) -> NSImage? {
        let localURL: URL?

        if let url = URL(string: string), url.isFileURL {
            localURL = url
        } else if string.hasPrefix("/") {
            localURL = URL(fileURLWithPath: string)
        } else {
            localURL = nil
        }

        guard let localURL,
              let image = NSImage(contentsOf: localURL) else {
            return nil
        }

        return image
    }

    private static func scriptError(from errorInfo: NSDictionary) -> AppleMusicScriptError {
        let errorNumber = (errorInfo[NSAppleScript.errorNumber] as? NSNumber)?.intValue
            ?? (errorInfo["NSAppleScriptErrorNumber"] as? NSNumber)?.intValue

        switch errorNumber {
        case -1743:
            return .permissionDenied
        case -600:
            return .applicationNotRunning
        default:
            return .failed
        }
    }

    private static let artworkDescriptorTypes: [DescType] = [
        typeJPEG,
        fourCharacterCode("PNGf"),
        fourCharacterCode("PNG "),
        typeTIFF,
        typePict,
        typeData
    ]

    private static func fourCharacterCode(_ string: String) -> DescType {
        string.utf8.reduce(0) { code, byte in
            (code << 8) | DescType(byte)
        }
    }

    private static let nowPlayingScript = """
    tell application id "com.apple.Music"
        set stateText to player state as text
        set trackTitle to ""
        set trackArtist to ""
        set trackAlbum to ""
        set trackArtwork to ""
        set trackDuration to ""
        set trackPosition to ""

        if stateText is not "stopped" then
            try
                set currentTrack to current track

                try
                    set trackTitle to name of currentTrack as text
                end try

                try
                    set trackArtist to artist of currentTrack as text
                end try

                try
                    set trackAlbum to album of currentTrack as text
                end try

                try
                    set trackDuration to ((duration of currentTrack) as integer) as text
                end try

                try
                    if (count of artworks of currentTrack) > 0 then
                        try
                            set trackArtwork to raw data of artwork 1 of currentTrack
                        on error
                            set trackArtwork to data of artwork 1 of currentTrack
                        end try
                    end if
                end try
            end try

            try
                set trackPosition to ((player position) as integer) as text
            end try
        end if

        return {stateText, trackTitle, trackArtist, trackAlbum, trackDuration, trackPosition, trackArtwork}
    end tell
    """
}
