import AppKit
import Combine
import CoreAudio
import CoreGraphics
import CoreServices
import Darwin
import Foundation
import IOKit
import IOKit.graphics
import IOKit.hidsystem
import IOKit.ps
import MacBookDynamicIslandCore
import os
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

private enum IslandMetrics {
    static let playerCompactSize = CGSize(width: 180, height: 30)
    static let playerExpandedSize = CGSize(width: 690, height: 126)
    static let playerLargeExpandedSize = CGSize(width: 790, height: 164)
    static let customHomeTwoWidgetSize = CGSize(width: 760, height: 154)
    static let customHomeTwoWidgetLargeSize = CGSize(width: 840, height: 180)
    static let customHomeThreeWidgetSize = CGSize(width: 850, height: 164)
    static let customHomeThreeWidgetLargeSize = CGSize(width: 910, height: 184)
    static let nbaExpandedSize = CGSize(width: 740, height: 134)
    static let nbaLargeExpandedSize = CGSize(width: 820, height: 134)
    static let nbaBoxScoreExpandedSize = CGSize(width: 740, height: 372)
    static let nbaBoxScoreLargeExpandedSize = CGSize(width: 820, height: 446)
    static let compactSize = CGSize(width: 300, height: 30)
    static let airPodsSize = CGSize(width: 340, height: 30)
    static let chargingSize = CGSize(width: 360, height: 30)
    static let systemControlSize = CGSize(width: 350, height: 30)
    static let dragSize = CGSize(width: 700, height: 154)
    static let expandedSize = CGSize(width: 740, height: 184)
    static let largeExpandedSize = CGSize(width: 840, height: 216)
    static let notchCoreWidth: CGFloat = 190
    static let compactTopRadius: CGFloat = 0
    static let compactBottomRadius: CGFloat = 13
    static let airPodsTopRadius: CGFloat = 10
    static let airPodsBottomRadius: CGFloat = 15
    static let chargingTopRadius: CGFloat = 10
    static let chargingBottomRadius: CGFloat = 15
    static let systemControlTopRadius = compactTopRadius
    static let systemControlBottomRadius = compactBottomRadius
    static let topInset: CGFloat = 0
    static let sideMargin: CGFloat = 16
}

private enum IslandDefaultsKey {
    static let backgroundOption = "island.appearance.backgroundOption"
    static let textOption = "island.appearance.textOption"
    static let sizeOption = "island.appearance.sizeOption"
    static let autoExpandOnHover = "island.behavior.autoExpandOnHover"
    static let weatherLocationInput = "island.weather.locationInput"
    static let weatherLocationName = "island.weather.locationName"
    static let weatherLatitude = "island.weather.latitude"
    static let weatherLongitude = "island.weather.longitude"
    static let nbaScoresEnabled = "island.nba.scoresEnabled"
    static let layoutMode = "island.layout.mode"
    static let homeWidgets = "island.layout.homeWidgets"
    static let showHomeWeather = "island.layout.showHomeWeather"
}

private enum IslandLayoutMode: String, CaseIterable, Hashable, Identifiable {
    case classicThreeModes
    case customTwoModes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classicThreeModes:
            return "Classic"
        case .customTwoModes:
            return "Two UI"
        }
    }
}

private enum HomeWidget: String, CaseIterable, Hashable, Identifiable {
    case appleMusic
    case calendar
    case nbaScores

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleMusic:
            return "Apple Music"
        case .calendar:
            return "Calendar"
        case .nbaScores:
            return "NBA Scores"
        }
    }

    var shortTitle: String {
        switch self {
        case .appleMusic:
            return "Music"
        case .calendar:
            return "Calendar"
        case .nbaScores:
            return "NBA"
        }
    }

    var systemName: String {
        switch self {
        case .appleMusic:
            return "music.note"
        case .calendar:
            return "calendar"
        case .nbaScores:
            return "basketball.fill"
        }
    }

    static let defaultOrder: [HomeWidget] = [.appleMusic, .calendar]
    static let optionOrder: [HomeWidget] = [.calendar, .appleMusic, .nbaScores]
}

private enum IslandSizeOption: String, CaseIterable, Identifiable {
    case standard = "default"
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Default"
        case .large:
            return "Large"
        }
    }
}

private enum IslandBackgroundOption: String, CaseIterable, Identifiable {
    case black
    case graphite
    case midnight
    case evergreen
    case bordeaux
    case porcelain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .black:
            return "Black"
        case .graphite:
            return "Graphite"
        case .midnight:
            return "Midnight"
        case .evergreen:
            return "Evergreen"
        case .bordeaux:
            return "Bordeaux"
        case .porcelain:
            return "Porcelain"
        }
    }

    var color: Color {
        switch self {
        case .black:
            return Color.black
        case .graphite:
            return Color(red: 0.075, green: 0.078, blue: 0.086)
        case .midnight:
            return Color(red: 0.025, green: 0.050, blue: 0.105)
        case .evergreen:
            return Color(red: 0.025, green: 0.105, blue: 0.085)
        case .bordeaux:
            return Color(red: 0.150, green: 0.035, blue: 0.060)
        case .porcelain:
            return Color(red: 0.910, green: 0.900, blue: 0.860)
        }
    }
}

private enum IslandTextOption: String, CaseIterable, Identifiable {
    case white
    case graphite
    case warm
    case ice
    case mint
    case amber

    var id: String { rawValue }

    var title: String {
        switch self {
        case .white:
            return "White"
        case .graphite:
            return "Graphite"
        case .warm:
            return "Warm"
        case .ice:
            return "Ice"
        case .mint:
            return "Mint"
        case .amber:
            return "Amber"
        }
    }

    var color: Color {
        switch self {
        case .white:
            return Color.white
        case .graphite:
            return Color(red: 0.075, green: 0.078, blue: 0.086)
        case .warm:
            return Color(red: 1.000, green: 0.945, blue: 0.840)
        case .ice:
            return Color(red: 0.760, green: 0.900, blue: 1.000)
        case .mint:
            return Color(red: 0.710, green: 1.000, blue: 0.850)
        case .amber:
            return Color(red: 1.000, green: 0.780, blue: 0.360)
        }
    }
}

private struct IslandTextColorKey: EnvironmentKey {
    static let defaultValue = Color.white
}

private extension EnvironmentValues {
    var islandTextColor: Color {
        get { self[IslandTextColorKey.self] }
        set { self[IslandTextColorKey.self] = newValue }
    }
}

private enum IslandMode: Hashable {
    case player
    case nba
    case workspace
}

private enum SystemControlFeedbackKind: Equatable {
    case volume
    case brightness

    func systemName(level: CGFloat) -> String {
        switch self {
        case .volume:
            if level <= 0.001 { return "speaker.slash.fill" }
            if level < 0.34 { return "speaker.wave.1.fill" }
            if level < 0.67 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        case .brightness:
            return level < 0.34 ? "sun.min.fill" : "sun.max.fill"
        }
    }

    var tint: Color {
        Color(red: 0.800, green: 0.940, blue: 1.000)
    }
}

private struct SystemControlFeedback: Identifiable, Equatable {
    let id: UUID
    let kind: SystemControlFeedbackKind
    let level: CGFloat

    init(kind: SystemControlFeedbackKind, level: Float) {
        id = UUID()
        self.kind = kind
        self.level = CGFloat(min(max(level, 0), 1))
    }
}

private enum NBABoxScoreSide: String, CaseIterable, Identifiable {
    case away
    case home

    var id: String { rawValue }
}

private enum MediaPlaybackState {
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

private struct MediaControlAvailability: Equatable {
    var playPause = false
    var previous = false
    var next = false
}

private enum NowPlayingAvailability {
    case available
    case musicNotOpen
    case permissionDenied
}

private struct NowPlayingInfo {
    var title: String?
    var artist: String?
    var album: String?
    var artwork: NSImage?
    var duration: TimeInterval?
    var position: TimeInterval?
    var sourceApp: String?
    var playbackState: MediaPlaybackState = .unknown
    var controls = MediaControlAvailability()
    var availability: NowPlayingAvailability = .musicNotOpen

    static let empty = NowPlayingInfo.musicNotOpen()

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

private enum WeatherAvailability: Equatable {
    case notConfigured
    case loading
    case available
    case failed
}

private struct WeatherLocation: Equatable {
    var name: String
    var latitude: Double
    var longitude: Double

    var displayName: String {
        name
    }
}

private struct WeatherInfo: Equatable {
    var locationName: String
    var temperatureFahrenheit: Int
    var weatherCode: Int
    var isDay: Bool
    var updatedAt: Date

    var temperatureText: String {
        "\(temperatureFahrenheit)°"
    }

    var systemName: String {
        switch weatherCode {
        case 0:
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55, 56, 57:
            return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86:
            return "cloud.snow.fill"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        }
    }
}

private struct ShelfFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    var displayName: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }

    var existsOnDisk: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func makeDragItemProvider() -> NSItemProvider {
        let provider = NSItemProvider(object: url as NSURL)
        provider.suggestedName = displayName
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.fileURL.identifier,
            visibility: .all
        ) { completion in
            completion(url.absoluteString.data(using: .utf8), nil)
            return nil
        }
        return provider
    }
}

private enum ClipboardKind {
    case image
    case link
    case text
}

private struct ClipboardEntry: Identifiable {
    let id: UUID
    let value: String
    let kind: ClipboardKind
    let image: NSImage?

    init(value: String, kind: ClipboardKind) {
        id = UUID()
        self.value = value
        self.kind = kind
        image = nil
    }

    init(image: NSImage) {
        id = UUID()
        value = Self.imageDisplayName(for: image)
        kind = .image
        self.image = image
    }

    private static func imageDisplayName(for image: NSImage) -> String {
        let representation = image.representations.max { first, second in
            first.pixelsWide * first.pixelsHigh < second.pixelsWide * second.pixelsHigh
        }
        let width = representation?.pixelsWide ?? Int(image.size.width.rounded())
        let height = representation?.pixelsHigh ?? Int(image.size.height.rounded())

        guard width > 0, height > 0 else { return "Image" }
        return "Image \(width)x\(height)"
    }
}

private enum AppleMusicCommand {
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

private enum AppleMusicCommandResult {
    case sent
    case musicNotOpen
    case permissionDenied
    case failed
}

private enum AppleMusicScriptError: Error {
    case permissionDenied
    case applicationNotRunning
    case failed
}

@MainActor
private final class AppleMusicNowPlayingProvider {
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

private enum AppleMusicArtworkLookup {
    static func fetchArtworkData(searchTerms: [String]) async -> Data? {
        for searchTerm in searchTerms {
            for entity in SearchEntity.allCases {
                guard let searchURL = searchURL(for: searchTerm, entity: entity) else { continue }

                do {
                    let (searchData, searchResponse) = try await session.data(from: searchURL)
                    guard isSuccessfulHTTPResponse(searchResponse),
                          let artworkURL = try artworkURL(from: searchData) else {
                        continue
                    }

                    let (artworkData, artworkResponse) = try await session.data(from: artworkURL)
                    guard isSuccessfulHTTPResponse(artworkResponse), !artworkData.isEmpty else {
                        continue
                    }

                    return artworkData
                } catch {
                    continue
                }
            }
        }

        return nil
    }

    private static func searchURL(for searchTerm: String, entity: SearchEntity) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: searchTerm),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: entity.rawValue),
            URLQueryItem(name: "country", value: "US"),
            URLQueryItem(name: "limit", value: "10")
        ]
        return components?.url
    }

    private static func artworkURL(from data: Data) throws -> URL? {
        let response = try JSONDecoder().decode(ArtworkSearchResponse.self, from: data)

        for result in response.results {
            guard let artworkURL = result.artworkURL else { continue }
            return largerArtworkURL(from: artworkURL)
        }

        return nil
    }

    private static func largerArtworkURL(from url: URL) -> URL {
        let urlString = url.absoluteString
            .replacingOccurrences(of: "100x100bb", with: "600x600bb")
            .replacingOccurrences(of: "100x100-75", with: "600x600-75")
        return URL(string: urlString) ?? url
    }

    private static func isSuccessfulHTTPResponse(_ response: URLResponse) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(httpResponse.statusCode)
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        return URLSession(configuration: configuration)
    }()

    private struct ArtworkSearchResponse: Decodable {
        var results: [ArtworkSearchResult]
    }

    private struct ArtworkSearchResult: Decodable {
        var artworkURL: URL?

        enum CodingKeys: String, CodingKey {
            case artworkURL = "artworkUrl100"
        }
    }

    private enum SearchEntity: String, CaseIterable {
        case song
        case album
    }
}

private let weatherLog = Logger(subsystem: "local.hannan.MacBookDynamicIslandApp", category: "weather")

private enum OpenMeteoWeatherProvider {
    static func fetchWeather(forCity query: String) async throws -> (WeatherLocation, WeatherInfo) {
        let location = try await resolveLocation(for: query)
        let info = try await fetchWeather(for: location)
        return (location, info)
    }

    static func fetchWeather(for location: WeatherLocation) async throws -> WeatherInfo {
        guard let weatherURL = weatherURL(for: location) else {
            throw WeatherLookupError.invalidURL
        }

        let (data, response) = try await data(from: weatherURL)
        guard isSuccessfulHTTPResponse(response) else {
            throw WeatherLookupError.badResponse
        }

        let forecast = try JSONDecoder().decode(ForecastResponse.self, from: data)
        return WeatherInfo(
            locationName: location.displayName,
            temperatureFahrenheit: Int(forecast.current.temperature2m.rounded()),
            weatherCode: forecast.current.weatherCode,
            isDay: forecast.current.isDay == 1,
            updatedAt: Date()
        )
    }

    private static func resolveLocation(for query: String) async throws -> WeatherLocation {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            throw WeatherLookupError.emptyQuery
        }

        guard let geocodingURL = geocodingURL(for: trimmedQuery) else {
            throw WeatherLookupError.invalidURL
        }

        let (data, response) = try await data(from: geocodingURL)
        guard isSuccessfulHTTPResponse(response) else {
            throw WeatherLookupError.badResponse
        }

        let geocoding = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        guard let result = geocoding.results?.first else {
            throw WeatherLookupError.locationNotFound
        }

        return WeatherLocation(
            name: displayName(for: result),
            latitude: result.latitude,
            longitude: result.longitude
        )
    }

    private static func geocodingURL(for query: String) -> URL? {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ]
        return components?.url
    }

    private static func weatherURL(for location: WeatherLocation) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        return components?.url
    }

    private static func displayName(for result: GeocodingResult) -> String {
        var pieces = [result.name]

        if let admin1 = result.admin1?.trimmingCharacters(in: .whitespacesAndNewlines),
           !admin1.isEmpty,
           admin1.caseInsensitiveCompare(result.name) != .orderedSame {
            pieces.append(admin1)
        }

        if let country = result.country?.trimmingCharacters(in: .whitespacesAndNewlines),
           !country.isEmpty,
           !pieces.contains(where: { $0.caseInsensitiveCompare(country) == .orderedSame }) {
            pieces.append(country)
        }

        return pieces.joined(separator: ", ")
    }

    private static func isSuccessfulHTTPResponse(_ response: URLResponse) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(httpResponse.statusCode)
    }

    /// Fetches a URL, retrying once on transient network errors (timeout, connection
    /// lost, DNS hiccup) so a single flaky request doesn't fail the whole update.
    private static func data(from url: URL) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(from: url)
        } catch let error as URLError where Self.transientCodes.contains(error.code) {
            weatherLog.notice("Transient weather network error (\(error.code.rawValue, privacy: .public)); retrying once")
            try await Task.sleep(nanoseconds: 800_000_000)
            return try await session.data(from: url)
        }
    }

    private static let transientCodes: Set<URLError.Code> = [
        .timedOut, .networkConnectionLost, .cannotConnectToHost,
        .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet
    ]

    /// Maps any thrown error to a short, user-facing reason shown in Options.
    static func userMessage(for error: Error) -> String {
        if let lookupError = error as? WeatherLookupError {
            switch lookupError {
            case .emptyQuery:
                return "Enter a city name"
            case .locationNotFound:
                return "City not found — check spelling"
            case .invalidURL, .badResponse:
                return "Weather service unavailable"
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost:
                return "No internet connection"
            case .timedOut, .networkConnectionLost:
                return "Weather request timed out"
            default:
                return "Network error — try again"
            }
        }
        if error is DecodingError {
            return "Unexpected weather data"
        }
        return "Could not update weather"
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    enum WeatherLookupError: Error {
        case emptyQuery
        case invalidURL
        case badResponse
        case locationNotFound
    }

    private struct GeocodingResponse: Decodable {
        var results: [GeocodingResult]?
    }

    private struct GeocodingResult: Decodable {
        var name: String
        var latitude: Double
        var longitude: Double
        var admin1: String?
        var country: String?
    }

    private struct ForecastResponse: Decodable {
        var current: CurrentWeather
    }

    private struct CurrentWeather: Decodable {
        var temperature2m: Double
        var weatherCode: Int
        var isDay: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
            case isDay = "is_day"
        }
    }
}

private final class LiveNBAHTTPClient: NBAHTTPClient, @unchecked Sendable {
    static let shared = LiveNBAHTTPClient()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        session = URLSession(configuration: configuration)
    }

    func data(from url: URL) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NBADataError.badStatus(-1)
        }
        return (data, httpResponse)
    }
}

@MainActor
private final class IslandStore: ObservableObject {
    @Published var islandMode: IslandMode = .player
    @Published var nowPlaying = NowPlayingInfo.empty
    @Published var files: [ShelfFile] = []
    @Published var clipboardEntries: [ClipboardEntry] = []
    @Published var layoutMode: IslandLayoutMode {
        didSet {
            UserDefaults.standard.set(layoutMode.rawValue, forKey: IslandDefaultsKey.layoutMode)
            handleLayoutModeChange()
        }
    }
    @Published var homeWidgets: [HomeWidget] {
        didSet {
            UserDefaults.standard.set(homeWidgets.map(\.rawValue), forKey: IslandDefaultsKey.homeWidgets)
            handleHomeWidgetsChange()
        }
    }
    @Published var showHomeWeather: Bool {
        didSet {
            UserDefaults.standard.set(showHomeWeather, forKey: IslandDefaultsKey.showHomeWeather)
            handleHomeWeatherVisibilityChange()
        }
    }
    @Published var backgroundOption: IslandBackgroundOption {
        didSet {
            UserDefaults.standard.set(backgroundOption.rawValue, forKey: IslandDefaultsKey.backgroundOption)
        }
    }
    @Published var textOption: IslandTextOption {
        didSet {
            UserDefaults.standard.set(textOption.rawValue, forKey: IslandDefaultsKey.textOption)
        }
    }
    @Published var expandedSizeOption: IslandSizeOption {
        didSet {
            UserDefaults.standard.set(expandedSizeOption.rawValue, forKey: IslandDefaultsKey.sizeOption)
        }
    }
    @Published var autoExpandOnHover: Bool {
        didSet {
            UserDefaults.standard.set(autoExpandOnHover, forKey: IslandDefaultsKey.autoExpandOnHover)
        }
    }
    @Published var weatherLocationInput = "" {
        didSet {
            UserDefaults.standard.set(weatherLocationInput, forKey: IslandDefaultsKey.weatherLocationInput)
        }
    }
    @Published var weatherInfo: WeatherInfo?
    @Published var weatherStatus: WeatherAvailability = .notConfigured
    /// Specific reason shown in Options when `weatherStatus == .failed`.
    @Published var weatherErrorMessage: String?
    @Published var nbaScoresEnabled: Bool {
        didSet {
            UserDefaults.standard.set(nbaScoresEnabled, forKey: IslandDefaultsKey.nbaScoresEnabled)
            handleNBAScoresEnabledChange()
        }
    }
    @Published var nbaScoreboard: NBAScoreboard?
    @Published var nbaScoresStatus: NBAScoresStatus = .disabled
    @Published var selectedNBAGameID: String?
    @Published var nbaBoxScore: NBABoxScore?
    @Published var nbaBoxScoreStatus: NBAScoresStatus = .idle
    @Published var nbaBoxScoreSide: NBABoxScoreSide = .away
    @Published var isOptionsPresented = false
    @Published var isClipboardPaused = false {
        didSet {
            handleClipboardPauseChange()
        }
    }
    @Published var isExpanded = false {
        didSet {
            if !isExpanded {
                isOptionsPresented = false
            } else if islandMode == .player {
                refreshNowPlaying(afterNanoseconds: 560_000_000, onlyWhenPlayerExpanded: true)
                if isNBAModeVisible {
                    refreshNBAScoreboardIfVisible(force: false, manual: false)
                }
            } else if islandMode == .nba {
                refreshNBAScoreboardIfVisible(force: false, manual: false)
            }
        }
    }
    @Published var isDragTargeted = false
    @Published var airPodsBannerName: String?
    @Published var chargingBannerID: UUID?
    @Published var chargingBatteryPercent: Int?
    @Published var systemControlFeedback: SystemControlFeedback?
    @Published var isClipboardDetailHovered = false
    @Published var inspectedClipboardEntry: ClipboardEntry? {
        didSet {
            handleClipboardDetailChange(from: oldValue, to: inspectedClipboardEntry)
        }
    }

    private var clipboardTimer: Timer?
    private var audioOutputTimer: Timer?
    private var systemControlTimer: Timer?
    private var nowPlayingTimer: Timer?
    private var weatherTimer: Timer?
    private var nbaScoresTimer: Timer?
    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var displayBrightnessNotificationPort: IONotificationPortRef?
    private var displayBrightnessInterest: io_object_t = 0
    private var deferredNowPlayingRefreshTask: Task<Void, Never>?
    private var weatherRefreshTask: Task<Void, Never>?
    private var nbaScoreboardTask: Task<Void, Never>?
    private var nbaBoxScoreTask: Task<Void, Never>?
    private var lastPasteboardChangeCount: Int
    private var lastNowPlayingRefreshDate = Date.distantPast
    private var lastWeatherRefreshDate = Date.distantPast
    private var lastNBAScoreboardRefreshDate = Date.distantPast
    private var lastNBABoxScoreRefreshDates: [String: Date] = [:]
    private var nbaScoreboardFailureCount = 0
    private var nbaBoxScoreFailureCounts: [String: Int] = [:]
    private var nbaBoxScoreCache: [String: NBABoxScore] = [:]
    private var nbaBoxScoreCacheKeys: [String] = []
    private var lastOutputDeviceName: String?
    private var lastOutputWasAirPods = false
    private var lastOutputVolume: Float?
    private var lastDisplayBrightness: Float?
    private var lastPowerWasConnected = false
    private var weatherLocation: WeatherLocation?
    private var ambientRefreshPausedUntil = Date.distantPast
    private var airPodsBannerTask: Task<Void, Never>?
    private var chargingBannerTask: Task<Void, Never>?
    private var systemControlFeedbackTask: Task<Void, Never>?
    private var displayBrightnessRefreshTask: Task<Void, Never>?
    private var artworkLookupTask: Task<Void, Never>?
    private var pendingArtworkLookupKey: String?
    private var artworkCache: [String: Data] = [:]
    private var artworkCacheKeys: [String] = []
    private var artworkLookupMisses: [String: Date] = [:]
    private var suppressNextClipboardDetailDismissal = false
    private var shouldConsumeNextOutsideCollapse = false
    private var clipboardDetailDismissalGuardUntil = Date.distantPast
    private static let weatherRefreshInterval: TimeInterval = 30 * 60
    private static let artworkLookupMissRetryInterval: TimeInterval = 10 * 60
    private static let systemControlChangeThreshold: Float = 0.01
    private static let ioMessageServicePropertyChange = UInt32(0xE0000130)
    private typealias DisplayServicesGetBrightnessFunction = @convention(c) (
        CGDirectDisplayID,
        UnsafeMutablePointer<Float>
    ) -> Int32
    private static let displayServicesGetBrightness: DisplayServicesGetBrightnessFunction? = {
        let frameworkPath = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"

        guard let handle = dlopen(frameworkPath, RTLD_LAZY),
              let symbol = dlsym(handle, "DisplayServicesGetBrightness") else {
            return nil
        }

        return unsafeBitCast(symbol, to: DisplayServicesGetBrightnessFunction.self)
    }()

    private let concealedPasteboardTypes: Set<NSPasteboard.PasteboardType> = [
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")
    ]

    init() {
        let storedNBAScoresEnabled = UserDefaults.standard.bool(forKey: IslandDefaultsKey.nbaScoresEnabled)
        let storedShowHomeWeather = Self.storedShowHomeWeather()

        layoutMode = Self.storedLayoutMode()
        homeWidgets = Self.storedHomeWidgets()
        showHomeWeather = storedShowHomeWeather
        backgroundOption = Self.storedBackgroundOption()
        textOption = Self.storedTextOption()
        expandedSizeOption = Self.storedSizeOption()
        autoExpandOnHover = UserDefaults.standard.bool(forKey: IslandDefaultsKey.autoExpandOnHover)
        weatherLocationInput = Self.storedWeatherLocationInput()
        nbaScoresEnabled = storedNBAScoresEnabled
        weatherLocation = Self.storedWeatherLocation()
        weatherStatus = weatherLocation == nil ? .notConfigured : (storedShowHomeWeather ? .loading : .available)
        nbaScoresStatus = storedNBAScoresEnabled ? .idle : .disabled
        lastPasteboardChangeCount = NSPasteboard.general.changeCount
    }

    var islandBackgroundColor: Color {
        backgroundOption.color
    }

    var islandTextColor: Color {
        textOption.color
    }

    func expandedSize(for mode: IslandMode) -> CGSize {
        switch (mode, expandedSizeOption) {
        case (.player, .standard) where layoutMode == .customTwoModes:
            return customHomeExpandedSize
        case (.player, .large) where layoutMode == .customTwoModes:
            return customHomeExpandedSize
        case (.player, .standard):
            return IslandMetrics.playerExpandedSize
        case (.player, .large):
            return IslandMetrics.playerLargeExpandedSize
        case (.nba, .standard):
            return selectedNBAGameID == nil ? IslandMetrics.nbaExpandedSize : IslandMetrics.nbaBoxScoreExpandedSize
        case (.nba, .large):
            return selectedNBAGameID == nil ? IslandMetrics.nbaLargeExpandedSize : IslandMetrics.nbaBoxScoreLargeExpandedSize
        case (.workspace, .standard):
            return IslandMetrics.expandedSize
        case (.workspace, .large):
            return IslandMetrics.largeExpandedSize
        }
    }

    var visibleModes: [IslandMode] {
        switch layoutMode {
        case .classicThreeModes:
            return [.player, .nba, .workspace]
        case .customTwoModes:
            return [.player, .workspace]
        }
    }

    var visibleHomeWidgets: [HomeWidget] {
        let uniqueWidgets = Self.uniquedHomeWidgets(homeWidgets)
        return uniqueWidgets.isEmpty ? HomeWidget.defaultOrder : uniqueWidgets
    }

    private var customHomeExpandedSize: CGSize {
        let widgetCount = visibleHomeWidgets.count

        switch (widgetCount, expandedSizeOption) {
        case (0...1, .standard):
            return IslandMetrics.playerExpandedSize
        case (0...1, .large):
            return IslandMetrics.playerLargeExpandedSize
        case (2, .standard):
            return IslandMetrics.customHomeTwoWidgetSize
        case (2, .large):
            return IslandMetrics.customHomeTwoWidgetLargeSize
        case (_, .standard):
            return IslandMetrics.customHomeThreeWidgetSize
        case (_, .large):
            return IslandMetrics.customHomeThreeWidgetLargeSize
        }
    }

    func isHomeWidgetSelected(_ widget: HomeWidget) -> Bool {
        visibleHomeWidgets.contains(widget)
    }

    func canRemoveHomeWidget(_ widget: HomeWidget) -> Bool {
        isHomeWidgetSelected(widget) && visibleHomeWidgets.count > 1
    }

    func toggleHomeWidget(_ widget: HomeWidget) {
        var widgets = visibleHomeWidgets

        if let index = widgets.firstIndex(of: widget) {
            guard widgets.count > 1 else { return }
            widgets.remove(at: index)
        } else {
            widgets.append(widget)
        }

        homeWidgets = widgets
    }

    func moveHomeWidget(_ widget: HomeWidget, around targetWidget: HomeWidget) {
        var widgets = visibleHomeWidgets
        guard widget != targetWidget,
              let fromIndex = widgets.firstIndex(of: widget),
              let targetIndex = widgets.firstIndex(of: targetWidget) else { return }

        let movedWidget = widgets.remove(at: fromIndex)
        widgets.insert(movedWidget, at: targetIndex)
        homeWidgets = widgets
    }

    func modeTitle(for mode: IslandMode) -> String {
        switch mode {
        case .player:
            return layoutMode == .customTwoModes ? "First UI" : "Music"
        case .nba:
            return "NBA"
        case .workspace:
            return "Files and clipboard"
        }
    }

    func modeSystemName(for mode: IslandMode) -> String {
        switch mode {
        case .player:
            return layoutMode == .customTwoModes ? "rectangle.grid.2x2" : "music.note"
        case .nba:
            return "basketball.fill"
        case .workspace:
            return "doc.on.clipboard"
        }
    }

    func resetAppearance() {
        backgroundOption = .black
        textOption = .white
        expandedSizeOption = .standard
        autoExpandOnHover = false
    }

    func startClipboardWatcher() {
        clipboardTimer?.invalidate()

        let timer = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollClipboardFromTimer()
            }
        }
        timer.tolerance = 0.25

        clipboardTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func startNowPlayingWatcher() {
        nowPlayingTimer?.invalidate()
        refreshNowPlaying()

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNowPlayingFromTimer()
            }
        }
        timer.tolerance = 0.35

        nowPlayingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func startAirPodsWatcher() {
        audioOutputTimer?.invalidate()
        refreshCurrentAudioOutput(triggerBanner: false)

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshCurrentAudioOutputFromTimer(triggerBanner: true)
            }
        }
        timer.tolerance = 0.35

        audioOutputTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func startSystemControlWatcher() {
        systemControlTimer?.invalidate()
        refreshSystemControls(showFeedback: false)
        startDisplayBrightnessWatcher()

        let timer = Timer(timeInterval: 0.22, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSystemControlsFromTimer()
            }
        }
        timer.tolerance = 0.08

        systemControlTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func startPowerWatcher() {
        if let powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSourceRunLoopSource, .commonModes)
            self.powerSourceRunLoopSource = nil
        }

        lastPowerWasConnected = Self.isConnectedToPower()

        guard let source = IOPSNotificationCreateRunLoopSource(
            { context in
                guard let context else { return }
                let store = Unmanaged<IslandStore>.fromOpaque(context).takeUnretainedValue()

                Task { @MainActor in
                    store.refreshPowerSourceFromNotification()
                }
            },
            Unmanaged.passUnretained(self).toOpaque()
        )?.takeRetainedValue() else {
            return
        }

        powerSourceRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private func startDisplayBrightnessWatcher() {
        stopDisplayBrightnessWatcher()

        guard let service = Self.currentAppleARMBacklightService() else { return }
        defer { IOObjectRelease(service) }

        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)

        var interest: io_object_t = 0
        let status = IOServiceAddInterestNotification(
            port,
            service,
            kIOGeneralInterest,
            { context, _, messageType, _ in
                guard messageType == IslandStore.ioMessageServicePropertyChange,
                      let context else {
                    return
                }

                let store = Unmanaged<IslandStore>.fromOpaque(context).takeUnretainedValue()
                Task { @MainActor in
                    store.refreshBrightnessFromDisplayNotification()
                }
            },
            Unmanaged.passUnretained(self).toOpaque(),
            &interest
        )

        guard status == KERN_SUCCESS else {
            IONotificationPortDestroy(port)
            return
        }

        displayBrightnessNotificationPort = port
        displayBrightnessInterest = interest
    }

    private func stopDisplayBrightnessWatcher() {
        if displayBrightnessInterest != 0 {
            IOObjectRelease(displayBrightnessInterest)
            displayBrightnessInterest = 0
        }

        if let displayBrightnessNotificationPort {
            IONotificationPortDestroy(displayBrightnessNotificationPort)
            self.displayBrightnessNotificationPort = nil
        }
    }

    func startWeatherWatcher() {
        weatherTimer?.invalidate()
        if showHomeWeather {
            refreshWeatherIfConfigured(force: true)
        }

        let timer = Timer(timeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshWeatherFromTimer()
            }
        }
        timer.tolerance = 20.0

        weatherTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

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

    func shutdown() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
        audioOutputTimer?.invalidate()
        audioOutputTimer = nil
        systemControlTimer?.invalidate()
        systemControlTimer = nil
        nowPlayingTimer?.invalidate()
        nowPlayingTimer = nil
        weatherTimer?.invalidate()
        weatherTimer = nil
        nbaScoresTimer?.invalidate()
        nbaScoresTimer = nil
        if let powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSourceRunLoopSource, .commonModes)
            self.powerSourceRunLoopSource = nil
        }
        stopDisplayBrightnessWatcher()
        deferredNowPlayingRefreshTask?.cancel()
        deferredNowPlayingRefreshTask = nil
        weatherRefreshTask?.cancel()
        weatherRefreshTask = nil
        nbaScoreboardTask?.cancel()
        nbaScoreboardTask = nil
        nbaBoxScoreTask?.cancel()
        nbaBoxScoreTask = nil
        airPodsBannerTask?.cancel()
        airPodsBannerTask = nil
        chargingBannerTask?.cancel()
        chargingBannerTask = nil
        systemControlFeedbackTask?.cancel()
        systemControlFeedbackTask = nil
        displayBrightnessRefreshTask?.cancel()
        displayBrightnessRefreshTask = nil
        artworkLookupTask?.cancel()
        artworkLookupTask = nil
        pendingArtworkLookupKey = nil
        artworkCache.removeAll()
        artworkCacheKeys.removeAll()
        artworkLookupMisses.removeAll()
        airPodsBannerName = nil
        chargingBannerID = nil
        chargingBatteryPercent = nil
        systemControlFeedback = nil
        weatherInfo = nil
        clearNBAData()
        isClipboardDetailHovered = false
        nowPlaying = .empty
        clearClipboardHistory()
        files.removeAll()
    }

    func showPlayerMode() {
        closeClipboardDetail()
        islandMode = .player
        if isExpanded {
            refreshNowPlaying(afterNanoseconds: 460_000_000, onlyWhenPlayerExpanded: true)
        }
    }

    func showNBAMode() {
        guard visibleModes.contains(.nba) else {
            showPlayerMode()
            return
        }

        closeClipboardDetail()
        islandMode = .nba
        refreshNBAScoreboardIfVisible(force: false, manual: false)
    }

    func showWorkspaceMode() {
        islandMode = .workspace
    }

    func showNextMode() {
        showMode(offset: 1)
    }

    func showPreviousMode() {
        showMode(offset: -1)
    }

    private func showMode(offset: Int) {
        let modes = visibleModes
        guard let index = modes.firstIndex(of: islandMode) else {
            showPlayerMode()
            return
        }

        let nextIndex = (index + offset + modes.count) % modes.count
        switch modes[nextIndex] {
        case .player:
            showPlayerMode()
        case .nba:
            showNBAMode()
        case .workspace:
            showWorkspaceMode()
        }
    }

    func pauseAmbientRefreshes(for duration: TimeInterval) {
        ambientRefreshPausedUntil = max(ambientRefreshPausedUntil, Date().addingTimeInterval(duration))
    }

    var canApplyWeatherLocation: Bool {
        weatherStatus != .loading
            && weatherLocationInput.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    var weatherOptionsStatusText: String {
        switch weatherStatus {
        case .notConfigured:
            return "Off until a city is saved"
        case .loading:
            return "Checking weather…"
        case .available:
            guard let weatherInfo else { return "Weather ready" }
            return "\(weatherInfo.locationName) · \(weatherInfo.temperatureText)"
        case .failed:
            return weatherErrorMessage ?? "Could not update weather"
        }
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

    func applyWeatherLocationFromInput() {
        let query = weatherLocationInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if query.isEmpty {
            clearWeatherLocation()
            return
        }

        guard query.count >= 2 else {
            weatherErrorMessage = "Enter a city name"
            weatherStatus = .failed
            return
        }

        weatherLocationInput = query
        weatherRefreshTask?.cancel()
        weatherErrorMessage = nil
        weatherStatus = .loading

        weatherRefreshTask = Task { [weak self, query] in
            do {
                let result = try await OpenMeteoWeatherProvider.fetchWeather(forCity: query)
                guard !Task.isCancelled else { return }
                weatherLog.info("Weather city lookup succeeded: \(result.0.displayName, privacy: .public) \(result.1.temperatureFahrenheit, privacy: .public)°F")

                await MainActor.run {
                    guard let self else { return }

                    self.weatherLocation = result.0
                    self.storeWeatherLocation(result.0)
                    self.weatherLocationInput = result.0.displayName
                    self.weatherInfo = result.1
                    self.weatherErrorMessage = nil
                    self.weatherStatus = .available
                    self.lastWeatherRefreshDate = Date()
                    self.weatherRefreshTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                weatherLog.error("Weather city lookup failed for \"\(query, privacy: .public)\": \(String(describing: error), privacy: .public)")

                await MainActor.run {
                    guard let self else { return }
                    self.weatherErrorMessage = OpenMeteoWeatherProvider.userMessage(for: error)
                    self.weatherStatus = .failed
                    self.weatherRefreshTask = nil
                }
            }
        }
    }

    func clearWeatherLocation() {
        weatherRefreshTask?.cancel()
        weatherRefreshTask = nil
        weatherLocation = nil
        weatherInfo = nil
        weatherErrorMessage = nil
        weatherStatus = .notConfigured
        weatherLocationInput = ""
        lastWeatherRefreshDate = Date.distantPast
        UserDefaults.standard.removeObject(forKey: IslandDefaultsKey.weatherLocationName)
        UserDefaults.standard.removeObject(forKey: IslandDefaultsKey.weatherLatitude)
        UserDefaults.standard.removeObject(forKey: IslandDefaultsKey.weatherLongitude)
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

    func addFile(_ url: URL) {
        guard url.isFileURL else { return }

        files.removeAll { $0.url == url }
        files.insert(ShelfFile(url: url), at: 0)
        keepFiveFiles()
    }

    func removeFile(_ file: ShelfFile) {
        files.removeAll { $0.id == file.id }
    }

    func revealFile(_ file: ShelfFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    func clearClipboardHistory() {
        closeClipboardDetail()
        clipboardEntries.removeAll()
    }

    func inspectClipboardEntry(_ entry: ClipboardEntry) {
        pauseAmbientRefreshes(for: 0.28)
        clipboardDetailDismissalGuardUntil = Date.distantPast
        isClipboardDetailHovered = false
        shouldConsumeNextOutsideCollapse = false
        inspectedClipboardEntry = entry
    }

    func closeClipboardDetail() {
        guardNextClipboardDetailDismissal()
        suppressNextClipboardDetailDismissal = true
        inspectedClipboardEntry = nil
    }

    func setClipboardDetailFromPopover(_ entry: ClipboardEntry?) {
        if entry == nil {
            pauseAmbientRefreshes(for: 0.32)
            isClipboardDetailHovered = false
        }

        inspectedClipboardEntry = entry
    }

    func setClipboardDetailHovered(_ isHovered: Bool) {
        isClipboardDetailHovered = isHovered && inspectedClipboardEntry != nil
    }

    func consumeOutsideClickForClipboardDetailIfNeeded() -> Bool {
        if inspectedClipboardEntry != nil {
            closeClipboardDetail()
            return true
        }

        if shouldConsumeNextOutsideCollapse {
            shouldConsumeNextOutsideCollapse = false
            return true
        }

        if Date() < clipboardDetailDismissalGuardUntil {
            return true
        }

        return false
    }

    var isClipboardDetailDismissing: Bool {
        Date() < clipboardDetailDismissalGuardUntil
    }

    func copyClipboardEntry(_ entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general

        switch entry.kind {
        case .image:
            guard let image = entry.image else { return }
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
        case .link, .text:
            pasteboard.clearContents()
            pasteboard.setString(entry.value, forType: .string)
        }

        lastPasteboardChangeCount = pasteboard.changeCount
    }

    func togglePlayPause() {
        guard nowPlaying.canControl else { return }
        handleMusicCommandResult(AppleMusicNowPlayingProvider.shared.send(.togglePlayPause))
        refreshNowPlaying(afterNanoseconds: 180_000_000)
    }

    func playPreviousTrack() {
        guard nowPlaying.controls.previous, nowPlaying.hasContent else { return }
        handleMusicCommandResult(AppleMusicNowPlayingProvider.shared.send(.previousTrack))
        refreshNowPlaying(afterNanoseconds: 220_000_000)
    }

    func playNextTrack() {
        guard nowPlaying.controls.next, nowPlaying.hasContent else { return }
        handleMusicCommandResult(AppleMusicNowPlayingProvider.shared.send(.nextTrack))
        refreshNowPlaying(afterNanoseconds: 220_000_000)
    }

    private var isNBAModeVisible: Bool {
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

    private func handleNBAScoresEnabledChange() {
        guard nbaScoresEnabled else {
            clearNBAData()
            nbaScoresStatus = .disabled
            return
        }

        nbaScoresStatus = .idle
        refreshNBAScoreboardIfVisible(force: true, manual: false)
    }

    private func handleLayoutModeChange() {
        if layoutMode == .customTwoModes, islandMode == .nba {
            showPlayerMode()
        }

        if isExpanded, isNBAModeVisible {
            refreshNBAScoreboardIfVisible(force: false, manual: false)
        }
    }

    private func handleHomeWidgetsChange() {
        let cleanedWidgets = Self.uniquedHomeWidgets(homeWidgets)

        if cleanedWidgets.isEmpty {
            homeWidgets = HomeWidget.defaultOrder
            return
        }

        if cleanedWidgets != homeWidgets {
            homeWidgets = cleanedWidgets
            return
        }

        if layoutMode == .customTwoModes, islandMode == .player, isExpanded {
            if visibleHomeWidgets.contains(.nbaScores) {
                refreshNBAScoreboardIfVisible(force: false, manual: false)
            } else {
                selectedNBAGameID = nil
                nbaBoxScore = nil
                nbaBoxScoreStatus = .idle
            }
        }
    }

    private func handleHomeWeatherVisibilityChange() {
        if showHomeWeather {
            refreshWeatherIfConfigured(force: true)
            return
        }

        weatherRefreshTask?.cancel()
        weatherRefreshTask = nil
    }

    private func clearNBAData() {
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

    private func handleClipboardPauseChange() {
        guard !isClipboardPaused else { return }
        lastPasteboardChangeCount = NSPasteboard.general.changeCount
    }

    private func handleClipboardDetailChange(from oldValue: ClipboardEntry?, to newValue: ClipboardEntry?) {
        guard oldValue != nil, newValue == nil else {
            suppressNextClipboardDetailDismissal = false
            return
        }

        isClipboardDetailHovered = false
        guardNextClipboardDetailDismissal()

        if suppressNextClipboardDetailDismissal {
            suppressNextClipboardDetailDismissal = false
        } else {
            shouldConsumeNextOutsideCollapse = true
        }
    }

    private func guardNextClipboardDetailDismissal() {
        clipboardDetailDismissalGuardUntil = max(
            clipboardDetailDismissalGuardUntil,
            Date().addingTimeInterval(0.45)
        )
    }

    private static func storedBackgroundOption() -> IslandBackgroundOption {
        guard let rawValue = UserDefaults.standard.string(forKey: IslandDefaultsKey.backgroundOption) else {
            return .black
        }

        return IslandBackgroundOption(rawValue: rawValue) ?? .black
    }

    private static func storedTextOption() -> IslandTextOption {
        guard let rawValue = UserDefaults.standard.string(forKey: IslandDefaultsKey.textOption) else {
            return .white
        }

        return IslandTextOption(rawValue: rawValue) ?? .white
    }

    private static func storedSizeOption() -> IslandSizeOption {
        guard let rawValue = UserDefaults.standard.string(forKey: IslandDefaultsKey.sizeOption) else {
            return .standard
        }

        return IslandSizeOption(rawValue: rawValue) ?? .standard
    }

    private static func storedLayoutMode() -> IslandLayoutMode {
        guard let rawValue = UserDefaults.standard.string(forKey: IslandDefaultsKey.layoutMode) else {
            return .classicThreeModes
        }

        return IslandLayoutMode(rawValue: rawValue) ?? .classicThreeModes
    }

    private static func storedHomeWidgets() -> [HomeWidget] {
        let rawValues = UserDefaults.standard.stringArray(forKey: IslandDefaultsKey.homeWidgets) ?? []
        let widgets = rawValues.compactMap(HomeWidget.init(rawValue:))
        let cleanedWidgets = uniquedHomeWidgets(widgets)
        return cleanedWidgets.isEmpty ? HomeWidget.defaultOrder : cleanedWidgets
    }

    private static func storedShowHomeWeather() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: IslandDefaultsKey.showHomeWeather) != nil else {
            return true
        }

        return defaults.bool(forKey: IslandDefaultsKey.showHomeWeather)
    }

    private static func uniquedHomeWidgets(_ widgets: [HomeWidget]) -> [HomeWidget] {
        var seen = Set<HomeWidget>()
        return widgets.filter { widget in
            guard !seen.contains(widget) else { return false }
            seen.insert(widget)
            return true
        }
    }

    private static func storedWeatherLocationInput() -> String {
        UserDefaults.standard.string(forKey: IslandDefaultsKey.weatherLocationInput) ?? ""
    }

    private static func storedWeatherLocation() -> WeatherLocation? {
        let defaults = UserDefaults.standard
        guard let name = defaults.string(forKey: IslandDefaultsKey.weatherLocationName),
              !name.isEmpty,
              defaults.object(forKey: IslandDefaultsKey.weatherLatitude) != nil,
              defaults.object(forKey: IslandDefaultsKey.weatherLongitude) != nil else {
            return nil
        }

        return WeatherLocation(
            name: name,
            latitude: defaults.double(forKey: IslandDefaultsKey.weatherLatitude),
            longitude: defaults.double(forKey: IslandDefaultsKey.weatherLongitude)
        )
    }

    private func storeWeatherLocation(_ location: WeatherLocation) {
        let defaults = UserDefaults.standard
        defaults.set(location.displayName, forKey: IslandDefaultsKey.weatherLocationName)
        defaults.set(location.latitude, forKey: IslandDefaultsKey.weatherLatitude)
        defaults.set(location.longitude, forKey: IslandDefaultsKey.weatherLongitude)
    }

    private func refreshNowPlaying(afterNanoseconds delay: UInt64 = 0, onlyWhenPlayerExpanded: Bool = false) {
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

        lastNowPlayingRefreshDate = Date()

        var refreshedInfo = AppleMusicNowPlayingProvider.shared.fetchNowPlaying()
        let previousArtworkLookupKey = nowPlaying.artworkLookupKey
        let refreshedArtworkLookupKey = refreshedInfo.artworkLookupKey
        let didChangeTrack = previousArtworkLookupKey != refreshedArtworkLookupKey

        if didChangeTrack, pendingArtworkLookupKey != refreshedArtworkLookupKey {
            artworkLookupTask?.cancel()
            artworkLookupTask = nil
            pendingArtworkLookupKey = nil
        }

        if let artworkLookupKey = refreshedArtworkLookupKey,
           refreshedInfo.artwork == nil,
           let cachedArtworkData = artworkCache[artworkLookupKey],
           let cachedArtwork = NSImage(data: cachedArtworkData) {
            refreshedInfo.artwork = cachedArtwork
        } else if didChangeTrack {
            refreshedInfo.artwork = nil
        }

        nowPlaying = refreshedInfo
        resolveArtworkIfNeeded(for: refreshedInfo)
    }

    private func refreshNowPlayingFromTimer() {
        guard !ambientRefreshesArePaused else { return }

        let refreshInterval: TimeInterval = isExpanded && islandMode == .player ? 1.0 : 4.0
        guard Date().timeIntervalSince(lastNowPlayingRefreshDate) >= refreshInterval else { return }

        refreshNowPlaying()
    }

    private func refreshWeatherFromTimer() {
        guard !ambientRefreshesArePaused else { return }
        guard showHomeWeather else { return }
        refreshWeatherIfConfigured(force: false)
    }

    private func refreshWeatherIfConfigured(force: Bool) {
        guard showHomeWeather else { return }

        guard let location = weatherLocation else {
            weatherStatus = .notConfigured
            return
        }

        guard force || Date().timeIntervalSince(lastWeatherRefreshDate) >= Self.weatherRefreshInterval else {
            return
        }

        guard weatherRefreshTask == nil else { return }
        if weatherInfo == nil {
            weatherStatus = .loading
        }

        weatherRefreshTask = Task { [weak self, location] in
            do {
                let info = try await OpenMeteoWeatherProvider.fetchWeather(for: location)
                guard !Task.isCancelled else { return }
                weatherLog.info("Weather refresh succeeded: \(info.locationName, privacy: .public) \(info.temperatureFahrenheit, privacy: .public)°F")

                await MainActor.run {
                    guard let self else { return }
                    self.weatherInfo = info
                    self.weatherErrorMessage = nil
                    self.weatherStatus = .available
                    self.lastWeatherRefreshDate = Date()
                    self.weatherRefreshTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                weatherLog.error("Weather refresh failed: \(String(describing: error), privacy: .public)")

                await MainActor.run {
                    guard let self else { return }
                    self.weatherErrorMessage = OpenMeteoWeatherProvider.userMessage(for: error)
                    self.weatherStatus = .failed
                    self.lastWeatherRefreshDate = Date()
                    self.weatherRefreshTask = nil
                }
            }
        }
    }

    private func refreshNBAScoresFromTimer() {
        guard !ambientRefreshesArePaused else { return }
        refreshNBAScoreboardIfVisible(force: false, manual: false)

        guard isNBABoxScoreVisible else { return }
        guard let selectedNBAGameID else { return }
        refreshNBABoxScore(for: selectedNBAGameID, force: false, manual: false)
    }

    private func refreshNBAScoreboardIfVisible(force: Bool, manual: Bool) {
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

    private func resolveArtworkIfNeeded(for info: NowPlayingInfo) {
        guard info.hasContent,
              info.artwork == nil,
              let artworkLookupKey = info.artworkLookupKey,
              !info.artworkSearchTerms.isEmpty,
              canRetryArtworkLookup(for: artworkLookupKey) else {
            if !info.hasContent {
                artworkLookupTask?.cancel()
                artworkLookupTask = nil
                pendingArtworkLookupKey = nil
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

    private func refreshCurrentAudioOutput(triggerBanner: Bool) {
        guard let name = Self.currentOutputDeviceName() else {
            lastOutputDeviceName = nil
            lastOutputWasAirPods = false
            return
        }

        let isAirPods = Self.isAirPodsDeviceName(name)
        let didSwitchToAirPods = isAirPods && (!lastOutputWasAirPods || lastOutputDeviceName != name)

        lastOutputDeviceName = name
        lastOutputWasAirPods = isAirPods

        if triggerBanner && didSwitchToAirPods {
            showAirPodsBanner(deviceName: name)
        }
    }

    private func refreshCurrentAudioOutputFromTimer(triggerBanner: Bool) {
        guard !ambientRefreshesArePaused else { return }
        refreshCurrentAudioOutput(triggerBanner: triggerBanner)
    }

    private func refreshSystemControls(showFeedback: Bool) {
        let currentVolume = Self.currentOutputVolume()
        if let currentVolume {
            if showFeedback,
               let lastOutputVolume,
               abs(currentVolume - lastOutputVolume) >= Self.systemControlChangeThreshold {
                showSystemControlFeedback(
                    kind: .volume,
                    level: currentVolume
                )
            }
            lastOutputVolume = currentVolume
        } else {
            lastOutputVolume = nil
        }

        let currentBrightness = Self.currentDisplayBrightness()
        if let currentBrightness {
            if showFeedback,
               let lastDisplayBrightness,
               abs(currentBrightness - lastDisplayBrightness) >= Self.systemControlChangeThreshold {
                showSystemControlFeedback(
                    kind: .brightness,
                    level: currentBrightness
                )
            }
            lastDisplayBrightness = currentBrightness
        } else {
            lastDisplayBrightness = nil
        }
    }

    private func refreshSystemControlsFromTimer() {
        refreshSystemControls(showFeedback: true)
    }

    private func refreshBrightnessFromDisplayNotification() {
        displayBrightnessRefreshTask?.cancel()
        refreshBrightnessFromNotification()

        displayBrightnessRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }

            refreshBrightnessFromNotification()
            displayBrightnessRefreshTask = nil
        }
    }

    private func refreshBrightnessFromNotification() {
        guard let currentBrightness = Self.currentDisplayBrightness() else {
            lastDisplayBrightness = nil
            return
        }

        let didChange = lastDisplayBrightness.map {
            abs(currentBrightness - $0) >= Self.systemControlChangeThreshold
        } ?? true

        lastDisplayBrightness = currentBrightness

        if didChange {
            showSystemControlFeedback(kind: .brightness, level: currentBrightness)
        }
    }

    func showBrightnessFeedbackFromSystemKey() {
        let immediateLevel = Self.currentDisplayBrightness() ?? lastDisplayBrightness ?? 0.5
        lastDisplayBrightness = immediateLevel
        showSystemControlFeedback(kind: .brightness, level: immediateLevel)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 90_000_000)
            guard let updatedLevel = Self.currentDisplayBrightness() else { return }

            lastDisplayBrightness = updatedLevel
            showSystemControlFeedback(kind: .brightness, level: updatedLevel)
        }
    }

    private func showSystemControlFeedback(
        kind: SystemControlFeedbackKind,
        level: Float
    ) {
        guard !isExpanded, !isDragTargeted else { return }

        let feedback = SystemControlFeedback(kind: kind, level: level)
        systemControlFeedbackTask?.cancel()
        systemControlFeedback = feedback

        systemControlFeedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 950_000_000)
            guard !Task.isCancelled,
                  systemControlFeedback?.id == feedback.id else { return }

            systemControlFeedback = nil
            systemControlFeedbackTask = nil
        }
    }

    private func showAirPodsBanner(deviceName: String) {
        guard !isExpanded, !isDragTargeted else { return }

        airPodsBannerTask?.cancel()
        airPodsBannerName = deviceName

        airPodsBannerTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            airPodsBannerName = nil
            airPodsBannerTask = nil
        }
    }

    private func refreshPowerSourceFromNotification() {
        let isConnected = Self.isConnectedToPower()
        let didConnect = isConnected && !lastPowerWasConnected
        lastPowerWasConnected = isConnected

        if didConnect {
            showChargingBanner()
        }
    }

    private func showChargingBanner() {
        guard !isExpanded, !isDragTargeted else { return }

        chargingBannerTask?.cancel()
        chargingBatteryPercent = Self.currentBatteryPercentage()
        chargingBannerID = UUID()

        chargingBannerTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_100_000_000)
            guard !Task.isCancelled else { return }
            chargingBannerID = nil
            chargingBatteryPercent = nil
            chargingBannerTask = nil
        }
    }

    private func pollClipboard() {
        guard !isClipboardPaused else { return }

        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        guard changeCount != lastPasteboardChangeCount else { return }

        lastPasteboardChangeCount = changeCount

        if pasteboard.types?.contains(where: { concealedPasteboardTypes.contains($0) }) == true {
            return
        }

        if let image = Self.clipboardImage(from: pasteboard) {
            addClipboardImage(image)
            return
        }

        if let string = pasteboard.string(forType: .string) {
            addClipboardString(string)
        }
    }

    private func pollClipboardFromTimer() {
        guard !ambientRefreshesArePaused else { return }
        pollClipboard()
    }

    private var ambientRefreshesArePaused: Bool {
        Date() < ambientRefreshPausedUntil
    }

    private func addClipboardString(_ rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        let kind = Self.clipboardKind(for: value)
        let entry = ClipboardEntry(value: value, kind: kind)

        clipboardEntries.removeAll { $0.value == value }
        clipboardEntries.insert(entry, at: 0)
        keepFiveClipboardEntries()
    }

    private func addClipboardImage(_ image: NSImage) {
        clipboardEntries.insert(ClipboardEntry(image: image), at: 0)
        keepFiveClipboardEntries()
    }

    private func keepFiveFiles() {
        if files.count > 5 {
            files = Array(files.prefix(5))
        }
    }

    private func keepFiveClipboardEntries() {
        if clipboardEntries.count > 5 {
            clipboardEntries = Array(clipboardEntries.prefix(5))
        }
    }

    private static func clipboardKind(for value: String) -> ClipboardKind {
        if let url = URL(string: value),
           let scheme = url.scheme?.lowercased(),
           ["http", "https", "file"].contains(scheme),
           url.host != nil || scheme == "file" {
            return .link
        }

        return .text
    }

    private static func clipboardImage(from pasteboard: NSPasteboard) -> NSImage? {
        guard pasteboard.canReadItem(withDataConformingToTypes: [UTType.image.identifier]),
              let image = NSImage(pasteboard: pasteboard),
              image.isValid else {
            return nil
        }

        return image.copy() as? NSImage ?? image
    }

    private static func isAirPodsDeviceName(_ name: String) -> Bool {
        name.localizedCaseInsensitiveContains("AirPods")
    }

    private static func currentDisplayBrightness() -> Float? {
        if let brightness = currentDisplayServicesBrightness() {
            return brightness
        }

        if let brightness = currentIODisplayBrightness() {
            return brightness
        }

        return currentAppleARMBacklightBrightness()
    }

    private static func currentDisplayServicesBrightness() -> Float? {
        guard let getBrightness = displayServicesGetBrightness else { return nil }

        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success,
              displayCount > 0 else {
            return nil
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetOnlineDisplayList(displayCount, &displays, &displayCount) == .success else {
            return nil
        }

        var values: [Float] = []

        for display in displays.prefix(Int(displayCount)) {
            var brightness: Float = 0
            let status = getBrightness(display, &brightness)

            guard status == 0, brightness.isFinite else { continue }
            values.append(min(max(brightness, 0), 1))
        }

        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Float(values.count)
    }

    private static func currentIODisplayBrightness() -> Float? {
        guard let matching = IOServiceMatching("IODisplayConnect") else { return nil }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var values: [Float] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var brightness: Float = 0
            let status = IODisplayGetFloatParameter(
                service,
                IOOptionBits(0),
                kIODisplayBrightnessKey as CFString,
                &brightness
            )

            if status == KERN_SUCCESS {
                values.append(min(max(brightness, 0), 1))
            }

            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Float(values.count)
    }

    private static func currentAppleARMBacklightBrightness() -> Float? {
        guard let matching = IOServiceMatching("AppleARMBacklight") else { return nil }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var values: [Float] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let brightness = appleARMBacklightBrightness(for: service) {
                values.append(brightness)
            }

            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Float(values.count)
    }

    private static func currentAppleARMBacklightService() -> io_service_t? {
        guard let matching = IOServiceMatching("AppleARMBacklight") else { return nil }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        return service == 0 ? nil : service
    }

    private static func appleARMBacklightBrightness(for service: io_service_t) -> Float? {
        guard let property = IORegistryEntryCreateCFProperty(
            service,
            "IODisplayParameters" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? [String: Any],
              let brightness = property["brightness"] as? [String: Any],
              let value = numericFloat(brightness["value"]),
              let maxValue = numericFloat(brightness["max"]),
              maxValue > 0 else {
            return nil
        }

        return min(max(value / maxValue, 0), 1)
    }

    private static func isConnectedToPower() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return false
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let state = description[kIOPSPowerSourceStateKey as String] as? String,
               state == kIOPSACPowerValue {
                return true
            }

            if let isCharging = description[kIOPSIsChargingKey as String] as? Bool,
               isCharging {
                return true
            }
        }

        return false
    }

    private static func currentBatteryPercentage() -> Int? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any],
                let currentCapacity = integerValue(description[kIOPSCurrentCapacityKey as String]) else {
                continue
            }

            let percent: Int
            if let maxCapacity = integerValue(description[kIOPSMaxCapacityKey as String]), maxCapacity > 0 {
                percent = Int((Double(currentCapacity) / Double(maxCapacity) * 100).rounded())
            } else {
                percent = currentCapacity
            }

            return min(max(percent, 0), 100)
        }

        return nil
    }

    private static func integerValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }

        if let value = value as? NSNumber {
            return value.intValue
        }

        return nil
    }

    private static func numericFloat(_ value: Any?) -> Float? {
        if let value = value as? Float {
            return value
        }

        if let value = value as? Double {
            return Float(value)
        }

        if let value = value as? Int {
            return Float(value)
        }

        if let value = value as? NSNumber {
            return value.floatValue
        }

        return nil
    }

    private static func currentOutputDeviceName() -> String? {
        guard let deviceID = defaultOutputDeviceID() else { return nil }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let namePointer = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
        namePointer.initialize(to: nil)
        defer {
            namePointer.deinitialize(count: 1)
            namePointer.deallocate()
        }

        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, namePointer)

        guard status == noErr, let name = namePointer.pointee else { return nil }
        return name as String
    }

    private static func currentOutputVolume() -> Float? {
        guard let deviceID = defaultOutputDeviceID() else { return nil }

        if let volume = outputVolumeScalar(
            for: deviceID,
            element: kAudioObjectPropertyElementMain
        ) {
            return volume
        }

        let channelVolumes = [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)]
            .compactMap { outputVolumeScalar(for: deviceID, element: $0) }

        guard !channelVolumes.isEmpty else { return nil }
        return channelVolumes.reduce(0, +) / Float(channelVolumes.count)
    }

    private static func outputVolumeScalar(
        for deviceID: AudioObjectID,
        element: AudioObjectPropertyElement
    ) -> Float? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)

        guard status == noErr else { return nil }
        return min(max(volume, 0), 1)
    }

    private static func defaultOutputDeviceID() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr, deviceID != AudioObjectID(kAudioObjectUnknown) else {
            return nil
        }

        return deviceID
    }
}

private final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override var acceptsFirstResponder: Bool { false }
}

@MainActor
private final class IslandWindowController {
    private let store: IslandStore
    private let panel: IslandPanel
    private var cancellables = Set<AnyCancellable>()
    private var globalMouseDownMonitor: Any?
    private var globalSystemControlMonitor: Any?
    private var localMouseDownMonitor: Any?
    private var localSwipeMonitor: Any?
    private var modeSwipeAccumulatedX: CGFloat = 0
    private var lastModeSwipeTime = Date.distantPast
    private var frameCollapseTask: Task<Void, Never>?
    private var lastRenderedExpansionState = false

    init(store: IslandStore) {
        self.store = store

        panel = IslandPanel(
            contentRect: CGRect(origin: .zero, size: IslandMetrics.playerCompactSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        configureContent()
        bindStore()
        installSystemControlKeyMonitoring()
    }

    func show() {
        updateFrame(animated: false)
        panel.orderFrontRegardless()
    }

    private func configurePanel() {
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.level = .statusBar
        panel.collectionBehavior = [.stationary, .ignoresCycle]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
    }

    private func configureContent() {
        let view = IslandRootView(
            store: store,
            prepareForExpansion: { [weak self] in
                self?.prepareForExpansion()
            }
        )
        let hostingController = NSHostingController(rootView: view)

        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = hostingController
    }

    private func bindStore() {
        Publishers.CombineLatest4(
            store.$isExpanded,
            store.$isDragTargeted,
            store.$airPodsBannerName,
            store.$chargingBannerID
        )
            .receive(on: RunLoop.main)
            .sink { [weak self] isExpanded, _, _, _ in
                guard let self else { return }

                self.handleWindowFrameChange(isExpanded: isExpanded)
                self.syncOutsideClickMonitoring()
            }
            .store(in: &cancellables)

        store.$systemControlFeedback
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, !self.store.isExpanded else { return }
                self.updateFrame(animated: self.panel.isVisible)
            }
            .store(in: &cancellables)

        store.$islandMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateFrame(animated: self.panel.isVisible)
            }
            .store(in: &cancellables)

        store.$expandedSizeOption
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.store.isExpanded else { return }
                self.updateFrame(animated: self.panel.isVisible)
            }
            .store(in: &cancellables)

        store.$selectedNBAGameID
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self,
                      self.store.isExpanded,
                      self.store.islandMode == .nba else { return }

                self.updateFrame(animated: self.panel.isVisible)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFrame(animated: false)
            }
            .store(in: &cancellables)
    }

    private func installSystemControlKeyMonitoring() {
        guard globalSystemControlMonitor == nil else { return }

        globalSystemControlMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            let subtype = event.subtype.rawValue
            let data1 = event.data1

            Task { @MainActor in
                self?.handleSystemControlKeyEvent(subtype: subtype, data1: data1)
            }
        }
    }

    private func handleSystemControlKeyEvent(subtype: Int16, data1: Int) {
        guard subtype == Int16(NX_SUBTYPE_AUX_CONTROL_BUTTONS) else { return }

        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyState = (data1 & 0x0000FF00) >> 8
        guard keyState == 0x0A,
              keyCode == NX_KEYTYPE_BRIGHTNESS_UP || keyCode == NX_KEYTYPE_BRIGHTNESS_DOWN else {
            return
        }

        store.showBrightnessFeedbackFromSystemKey()
    }

    private func handleWindowFrameChange(isExpanded: Bool) {
        frameCollapseTask?.cancel()
        frameCollapseTask = nil

        if isExpanded {
            lastRenderedExpansionState = true
            updateFrame(animated: panel.isVisible)
            return
        }

        if lastRenderedExpansionState {
            lastRenderedExpansionState = false
            frameCollapseTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 430_000_000)
                guard !Task.isCancelled, !store.isExpanded else { return }

                updateFrame(animated: false)
            }
            return
        }

        updateFrame(animated: panel.isVisible)
    }

    private func syncOutsideClickMonitoring() {
        if store.isExpanded {
            installOutsideClickMonitoring()
            installModeSwipeMonitoring()
        } else {
            removeOutsideClickMonitoring()
            removeModeSwipeMonitoring()
        }
    }

    private func installOutsideClickMonitoring() {
        let mouseDownEvents: NSEvent.EventTypeMask = [
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown
        ]

        if globalMouseDownMonitor == nil {
            globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseDownEvents) { [weak self] _ in
                Task { @MainActor in
                    self?.collapseFromOutsideClick()
                }
            }
        }

        if localMouseDownMonitor == nil {
            localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseDownEvents) { [weak self] event in
                let windowNumber = event.windowNumber
                let locationInWindow = event.locationInWindow

                Task { @MainActor in
                    self?.collapseFromLocalMouseDown(
                        windowNumber: windowNumber,
                        locationInWindow: locationInWindow
                    )
                }

                return event
            }
        }
    }

    private func removeOutsideClickMonitoring() {
        if let globalMouseDownMonitor {
            NSEvent.removeMonitor(globalMouseDownMonitor)
            self.globalMouseDownMonitor = nil
        }

        if let localMouseDownMonitor {
            NSEvent.removeMonitor(localMouseDownMonitor)
            self.localMouseDownMonitor = nil
        }
    }

    private func installModeSwipeMonitoring() {
        guard localSwipeMonitor == nil else { return }

        localSwipeMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            let windowNumber = event.windowNumber
            let locationInWindow = event.locationInWindow
            let scrollingDeltaX = event.scrollingDeltaX
            let scrollingDeltaY = event.scrollingDeltaY
            let phase = event.phase
            let momentumPhase = event.momentumPhase

            Task { @MainActor in
                self?.handleModeSwipe(
                    windowNumber: windowNumber,
                    locationInWindow: locationInWindow,
                    scrollingDeltaX: scrollingDeltaX,
                    scrollingDeltaY: scrollingDeltaY,
                    phase: phase,
                    momentumPhase: momentumPhase
                )
            }

            return event
        }
    }

    private func removeModeSwipeMonitoring() {
        if let localSwipeMonitor {
            NSEvent.removeMonitor(localSwipeMonitor)
            self.localSwipeMonitor = nil
        }
        modeSwipeAccumulatedX = 0
    }

    private func collapseFromOutsideClick() {
        guard store.isExpanded else { return }

        if store.isOptionsPresented {
            return
        }

        if store.consumeOutsideClickForClipboardDetailIfNeeded() {
            return
        }

        store.pauseAmbientRefreshes(for: 0.48)
        store.isExpanded = false
    }

    private func collapseFromLocalMouseDown(windowNumber: Int, locationInWindow: CGPoint) {
        guard store.isExpanded else { return }

        if windowNumber == panel.windowNumber,
           let contentView = panel.contentView {
            let contentPoint = contentView.convert(locationInWindow, from: nil)
            if contentView.bounds.contains(contentPoint) {
                return
            }
        }

        if store.inspectedClipboardEntry != nil {
            return
        }

        collapseFromOutsideClick()
    }

    private func handleModeSwipe(
        windowNumber: Int,
        locationInWindow: CGPoint,
        scrollingDeltaX: CGFloat,
        scrollingDeltaY: CGFloat,
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase
    ) {
        guard store.isExpanded,
              !store.isOptionsPresented,
              windowNumber == panel.windowNumber,
              modeSwipeIsInsideIsland(locationInWindow),
              momentumPhase == [] else {
            return
        }

        if phase == .ended || phase == .cancelled {
            modeSwipeAccumulatedX = 0
            return
        }

        if phase == .began {
            modeSwipeAccumulatedX = 0
        }

        guard abs(scrollingDeltaX) > max(2.5, abs(scrollingDeltaY) * 1.08) else {
            return
        }

        modeSwipeAccumulatedX += scrollingDeltaX
        guard abs(modeSwipeAccumulatedX) >= 12 else { return }

        let now = Date()
        guard now.timeIntervalSince(lastModeSwipeTime) > 0.26 else {
            modeSwipeAccumulatedX = 0
            return
        }
        lastModeSwipeTime = now

        store.pauseAmbientRefreshes(for: 0.34)
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.90, blendDuration: 0.08)) {
            if modeSwipeAccumulatedX < 0 {
                store.showNextMode()
            } else {
                store.showPreviousMode()
            }
        }

        modeSwipeAccumulatedX = 0
    }

    private func modeSwipeIsInsideIsland(_ locationInWindow: CGPoint) -> Bool {
        guard let contentView = panel.contentView else { return false }

        let contentPoint = contentView.convert(locationInWindow, from: nil)
        return contentView.bounds.contains(contentPoint)
    }

    private func prepareForExpansion() {
        let frame = ScreenPositioner.frame(for: expandedSizeForCurrentMode, on: panel.screen)
        if !Self.framesMatch(panel.frame, frame) {
            panel.setFrame(frame, display: true)
        }
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
    }

    private func updateFrame(animated: Bool) {
        let size = currentSize
        let frame = ScreenPositioner.frame(for: size, on: panel.screen)
        guard !Self.framesMatch(panel.frame, frame) else { return }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = store.isExpanded ? 0.34 : 0.36
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.20, 0.84, 0.22, 1.0)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private static func framesMatch(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < 0.5
            && abs(lhs.origin.y - rhs.origin.y) < 0.5
            && abs(lhs.size.width - rhs.size.width) < 0.5
            && abs(lhs.size.height - rhs.size.height) < 0.5
    }

    private var currentSize: CGSize {
        if store.isExpanded {
            return expandedSizeForCurrentMode
        }

        if store.isDragTargeted {
            return IslandMetrics.dragSize
        }

        if store.systemControlFeedback != nil {
            return IslandMetrics.systemControlSize
        }

        if store.chargingBannerID != nil {
            return IslandMetrics.chargingSize
        }

        if store.airPodsBannerName != nil {
            return IslandMetrics.airPodsSize
        }

        if store.islandMode == .player {
            return IslandMetrics.playerCompactSize
        }

        return IslandMetrics.compactSize
    }

    private var expandedSizeForCurrentMode: CGSize {
        store.expandedSize(for: store.islandMode)
    }
}

private enum ScreenPositioner {
    static func frame(for size: CGSize, on preferredScreen: NSScreen?) -> CGRect {
        let screen = preferredScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else {
            return CGRect(origin: .zero, size: size)
        }

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let notchCenterX = notchAwareCenterX(for: screen)
        let rawX = notchCenterX - (size.width / 2)
        let minX = visibleFrame.minX + IslandMetrics.sideMargin
        let maxX = visibleFrame.maxX - size.width - IslandMetrics.sideMargin
        let x = min(max(rawX, minX), maxX)
        let y = screenFrame.maxY - size.height + IslandMetrics.topInset

        return CGRect(
            x: x.rounded(.toNearestOrAwayFromZero),
            y: y.rounded(.toNearestOrAwayFromZero),
            width: size.width,
            height: size.height
        )
    }

    private static func notchAwareCenterX(for screen: NSScreen) -> CGFloat {
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea,
              !left.isEmpty,
              !right.isEmpty,
              left.maxX < right.minX else {
            return screen.frame.midX
        }

        return (left.maxX + right.minX) / 2
    }
}

private struct IslandRootView: View {
    @ObservedObject var store: IslandStore
    let prepareForExpansion: () -> Void
    private static let collapseCompactRevealDelay: UInt64 = 340_000_000
    @State private var surfaceSize = IslandMetrics.playerCompactSize
    @State private var surfaceTopRadius: CGFloat = IslandMetrics.compactTopRadius
    @State private var surfaceBottomRadius: CGFloat = IslandMetrics.compactBottomRadius
    @State private var rendersExpandedContent = false
    @State private var showsCompactContent = true
    @State private var showsExpandedContent = false
    @State private var expansionStartTask: Task<Void, Never>?
    @State private var contentRevealTask: Task<Void, Never>?
    @State private var hoverCollapseTask: Task<Void, Never>?
    @State private var isPointerInsideIsland = false

    var body: some View {
        GeometryReader { proxy in
            islandSurface
                .position(
                    x: proxy.size.width / 2,
                    y: surfaceSize.height / 2
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
        .onChange(of: store.isExpanded) { isExpanded in
            handleExpansionChange(isExpanded)
        }
        .onChange(of: store.isDragTargeted) { isDragTargeted in
            handleDragTargetChange(isDragTargeted)
        }
        .onChange(of: store.airPodsBannerName) { _ in
            handleCompactBannerChange()
        }
        .onChange(of: store.chargingBannerID) { _ in
            handleCompactBannerChange()
        }
        .onChange(of: store.systemControlFeedback) { _ in
            handleCompactBannerChange()
        }
        .onChange(of: store.islandMode) { _ in
            handleModeChange()
        }
        .onChange(of: store.layoutMode) { _ in
            handleExpandedSizeChange()
        }
        .onChange(of: store.homeWidgets) { _ in
            handleExpandedSizeChange()
        }
        .onChange(of: store.expandedSizeOption) { _ in
            handleExpandedSizeChange()
        }
        .onChange(of: store.selectedNBAGameID) { _ in
            handleNBASelectionChange()
        }
        .onChange(of: store.isClipboardDetailHovered) { isHovered in
            handleClipboardDetailHoverChange(isHovered)
        }
        .onDisappear {
            expansionStartTask?.cancel()
            contentRevealTask?.cancel()
            hoverCollapseTask?.cancel()
        }
    }

    private var islandSurface: some View {
        ZStack(alignment: .top) {
            IslandBackdrop(
                topRadius: surfaceTopRadius,
                bottomRadius: surfaceBottomRadius,
                backgroundColor: surfaceBackgroundColor
            )

            compactNotchAnchor

            content
                .environment(\.islandTextColor, store.islandTextColor)
        }
        .frame(width: surfaceSize.width, height: surfaceSize.height)
        .clipShape(IslandSurfaceShape(topRadius: surfaceTopRadius, bottomRadius: surfaceBottomRadius))
        .contentShape(IslandSurfaceShape(topRadius: surfaceTopRadius, bottomRadius: surfaceBottomRadius))
        .contextMenu {
            if store.isExpanded {
                Button {
                    store.isOptionsPresented = true
                } label: {
                    Label("Options…", systemImage: "slider.horizontal.3")
                }
            }
        }
        .popover(isPresented: $store.isOptionsPresented, arrowEdge: .top) {
            IslandOptionsPopoverView(store: store)
                .interactiveDismissDisabled(true)
        }
        .onHover { isHovering in
            handleHoverChange(isHovering)
        }
        .onTapGesture {
            guard !store.isExpanded else { return }

            prepareForExpansion()
            beginExpansion()
        }
        .onDrop(
            of: [UTType.fileURL.identifier],
            isTargeted: Binding(
                get: { store.isDragTargeted },
                set: { store.isDragTargeted = $0 }
            ),
            perform: handleDrop
        )
    }

    private var compactNotchAnchor: some View {
        IslandSurfaceShape(
            topRadius: transientCompactTopRadius,
            bottomRadius: transientCompactBottomRadius
        )
        .fill(surfaceBackgroundColor)
        .frame(width: transientCompactSize.width, height: transientCompactSize.height)
        .allowsHitTesting(false)
    }

    private var surfaceBackgroundColor: Color {
        if store.isDragTargeted || store.islandMode == .workspace {
            return .black
        }

        return store.islandBackgroundColor
    }

    @ViewBuilder
    private var content: some View {
        ZStack(alignment: .top) {
            CompactIslandView(store: store)
                .padding(contentInsets)
                .frame(
                    width: compactContentSize.width,
                    height: compactContentSize.height
                )
                .opacity(showsCompactContent ? 1 : 0)
                .allowsHitTesting(showsCompactContent && !rendersExpandedContent)
                .zIndex(store.isExpanded ? 0 : 2)

            if rendersExpandedContent {
                ExpandedIslandView(store: store)
                    .padding(expandedContentInsets)
                    .opacity(showsExpandedContent ? 1 : 0)
                    .scaleEffect(showsExpandedContent ? 1 : 0.99, anchor: .top)
                    .allowsHitTesting(showsExpandedContent)
                    .zIndex(store.isExpanded ? 2 : 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var bottomRadius: CGFloat {
        if store.isExpanded { return 28 }
        if store.isDragTargeted { return 22 }
        return 8
    }

    private var contentInsets: EdgeInsets {
        if store.isExpanded {
            return expandedContentInsets
        }

        if store.isDragTargeted {
            return EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        }

        return compactContentInsets
    }

    private var compactContentSize: CGSize {
        transientCompactSize
    }

    private var transientCompactSize: CGSize {
        if store.isDragTargeted { return IslandMetrics.dragSize }
        if store.systemControlFeedback != nil { return IslandMetrics.systemControlSize }
        if store.chargingBannerID != nil { return IslandMetrics.chargingSize }
        if store.airPodsBannerName != nil { return IslandMetrics.airPodsSize }
        return IslandMetrics.playerCompactSize
    }

    private var transientCompactTopRadius: CGFloat {
        if store.isDragTargeted { return 0 }
        if store.systemControlFeedback != nil { return IslandMetrics.systemControlTopRadius }
        if store.chargingBannerID != nil { return IslandMetrics.chargingTopRadius }
        if store.airPodsBannerName != nil { return IslandMetrics.airPodsTopRadius }
        return IslandMetrics.compactTopRadius
    }

    private var transientCompactBottomRadius: CGFloat {
        if store.isDragTargeted { return 22 }
        if store.systemControlFeedback != nil { return IslandMetrics.systemControlBottomRadius }
        if store.chargingBannerID != nil { return IslandMetrics.chargingBottomRadius }
        if store.airPodsBannerName != nil { return IslandMetrics.airPodsBottomRadius }
        return IslandMetrics.compactBottomRadius
    }

    private var compactContentInsets: EdgeInsets {
        return EdgeInsets(top: 4, leading: 18, bottom: 3, trailing: 18)
    }

    private var expandedContentInsets: EdgeInsets {
        if store.islandMode == .player {
            return EdgeInsets(top: 14, leading: 14, bottom: 11, trailing: 14)
        }

        return EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
    }

    private var expandedSurfaceSize: CGSize {
        store.expandedSize(for: store.islandMode)
    }

    private func handleExpansionChange(_ isExpanded: Bool) {
        contentRevealTask?.cancel()
        store.pauseAmbientRefreshes(for: 0.50)

        if isExpanded {
            rendersExpandedContent = false
            showsExpandedContent = false

            withAnimation(.easeOut(duration: 0.1)) {
                showsCompactContent = false
            }

            withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.92, blendDuration: 0.06)) {
                surfaceSize = expandedSurfaceSize
                surfaceTopRadius = 0
                surfaceBottomRadius = 28
            }

            contentRevealTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 55_000_000)
                guard !Task.isCancelled, store.isExpanded else { return }

                rendersExpandedContent = true

                try? await Task.sleep(nanoseconds: 16_000_000)
                guard !Task.isCancelled, store.isExpanded else { return }

                withAnimation(.easeOut(duration: 0.18)) {
                    showsExpandedContent = true
                }
            }
        } else {
            expansionStartTask?.cancel()

            showsCompactContent = false

            withAnimation(.easeOut(duration: 0.11)) {
                showsExpandedContent = false
            }

            withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.96, blendDuration: 0.06)) {
                surfaceSize = transientCompactSize
                surfaceTopRadius = transientCompactTopRadius
                surfaceBottomRadius = transientCompactBottomRadius
            }

            contentRevealTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: Self.collapseCompactRevealDelay)
                guard !Task.isCancelled, !store.isExpanded else { return }

                rendersExpandedContent = false
                withAnimation(.easeOut(duration: 0.10)) {
                    showsCompactContent = true
                }
            }
        }
    }

    private func beginExpansion() {
        expansionStartTask?.cancel()
        contentRevealTask?.cancel()
        hoverCollapseTask?.cancel()
        store.pauseAmbientRefreshes(for: 0.50)
        rendersExpandedContent = false
        showsCompactContent = true
        showsExpandedContent = false
        surfaceSize = transientCompactSize
        surfaceTopRadius = transientCompactTopRadius
        surfaceBottomRadius = transientCompactBottomRadius

        expansionStartTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled, !store.isExpanded else { return }

            store.isExpanded = true
        }
    }

    private func handleHoverChange(_ isHovering: Bool) {
        isPointerInsideIsland = isHovering

        guard store.autoExpandOnHover else {
            hoverCollapseTask?.cancel()
            return
        }

        if isHovering {
            hoverCollapseTask?.cancel()

            guard !store.isExpanded,
                  !store.isDragTargeted,
                  store.systemControlFeedback == nil,
                  store.chargingBannerID == nil,
                  store.airPodsBannerName == nil else {
                return
            }

            prepareForExpansion()
            beginExpansion()
            return
        }

        guard store.isExpanded else { return }
        scheduleHoverCollapse(after: 220_000_000)
    }

    private func handleClipboardDetailHoverChange(_ isHovered: Bool) {
        guard store.autoExpandOnHover,
              store.isExpanded,
              !isPointerInsideIsland else {
            return
        }

        hoverCollapseTask?.cancel()
        if !isHovered {
            scheduleHoverCollapse(after: 90_000_000)
        }
    }

    private func scheduleHoverCollapse(after delay: UInt64) {
        hoverCollapseTask?.cancel()
        hoverCollapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, shouldCollapseAfterHoverExit else { return }

            if store.inspectedClipboardEntry != nil {
                store.closeClipboardDetail()
                try? await Task.sleep(nanoseconds: 360_000_000)
                guard !Task.isCancelled, shouldCollapseAfterHoverExit else { return }
            } else if store.isClipboardDetailDismissing {
                try? await Task.sleep(nanoseconds: 260_000_000)
                guard !Task.isCancelled, shouldCollapseAfterHoverExit else { return }
            }

            store.pauseAmbientRefreshes(for: 0.48)
            store.isExpanded = false
        }
    }

    private var shouldCollapseAfterHoverExit: Bool {
        store.autoExpandOnHover
            && store.isExpanded
            && !store.isOptionsPresented
            && !isPointerInsideIsland
            && !store.isClipboardDetailHovered
    }

    private func handleDragTargetChange(_ isDragTargeted: Bool) {
        guard !store.isExpanded else { return }

        store.pauseAmbientRefreshes(for: 0.36)
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.06)) {
            surfaceSize = transientCompactSize
            surfaceTopRadius = transientCompactTopRadius
            surfaceBottomRadius = transientCompactBottomRadius
        }
    }

    private func handleModeChange() {
        let targetSize = store.isExpanded ? expandedSurfaceSize : transientCompactSize

        store.pauseAmbientRefreshes(for: 0.38)
        withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.90, blendDuration: 0.08)) {
            surfaceSize = targetSize
            surfaceTopRadius = store.isExpanded ? 0 : transientCompactTopRadius
            surfaceBottomRadius = store.isExpanded ? 28 : transientCompactBottomRadius
        }
    }

    private func handleExpandedSizeChange() {
        guard store.isExpanded else { return }

        store.pauseAmbientRefreshes(for: 0.38)
        withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.90, blendDuration: 0.08)) {
            surfaceSize = expandedSurfaceSize
            surfaceTopRadius = 0
            surfaceBottomRadius = 28
        }
    }

    private func handleNBASelectionChange() {
        guard store.isExpanded, store.islandMode == .nba else { return }

        store.pauseAmbientRefreshes(for: 0.38)
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.90, blendDuration: 0.08)) {
            surfaceSize = expandedSurfaceSize
            surfaceTopRadius = 0
            surfaceBottomRadius = 28
        }
    }

    private func handleCompactBannerChange() {
        guard !store.isExpanded else { return }

        store.pauseAmbientRefreshes(for: 0.46)
        withAnimation(.interactiveSpring(response: 0.42, dampingFraction: 0.94, blendDuration: 0.08)) {
            surfaceSize = transientCompactSize
            surfaceTopRadius = transientCompactTopRadius
            surfaceBottomRadius = transientCompactBottomRadius
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = Self.fileURL(from: item) else { return }

                Task { @MainActor in
                    store.addFile(url)
                    withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.90)) {
                        store.showWorkspaceMode()
                    }

                    if store.isExpanded {
                        return
                    }

                    prepareForExpansion()
                    beginExpansion()
                }
            }
        }

        return accepted
    }

    nonisolated private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL, url.isFileURL {
            return url
        }

        if let data = item as? Data,
           let url = URL(dataRepresentation: data, relativeTo: nil),
           url.isFileURL {
            return url
        }

        if let string = item as? String {
            if let url = URL(string: string), url.isFileURL {
                return url
            }

            let fileURL = URL(fileURLWithPath: string)
            return fileURL.isFileURL ? fileURL : nil
        }

        return nil
    }
}

private struct IslandSurfaceShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let topRadius = min(topRadius, rect.width / 2, rect.height / 2)
        let bottomRadius = min(bottomRadius, rect.width / 2, rect.height / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topRadius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY))

        if topRadius > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + topRadius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topRadius))

        if topRadius > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + topRadius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        } else {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }

        path.closeSubpath()

        return path
    }
}

private struct IslandBackdrop: View {
    let topRadius: CGFloat
    let bottomRadius: CGFloat
    let backgroundColor: Color

    var body: some View {
        let radius = bottomRadius

        IslandSurfaceShape(topRadius: topRadius, bottomRadius: bottomRadius)
            .fill(backgroundColor)
            .shadow(color: Color.black.opacity(radius > 24 ? 0.0 : 0.28), radius: radius > 24 ? 0 : 5, x: 0, y: radius > 24 ? 0 : 2)
    }
}

private struct IslandOptionsPopoverView: View {
    @ObservedObject var store: IslandStore
    @State private var selectedTab: IslandOptionsTab = .appearance
    @State private var isCloseHovered = false
    @State private var isResetHovered = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()
                .overlay(Color.white.opacity(0.10))

            activePanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(28)
        }
        .frame(width: 840, height: 500)
        .foregroundStyle(Color.white)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.055, green: 0.058, blue: 0.066).opacity(0.98),
                            Color(red: 0.030, green: 0.032, blue: 0.038).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.38), radius: 26, x: 0, y: 16)
        .environment(\.colorScheme, .dark)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 11) {
                Button {
                    store.pauseAmbientRefreshes(for: 0.34)
                    store.isOptionsPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .black))
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(isCloseHovered ? 0.16 : 0.10))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isCloseHovered ? 0.18 : 0.12), lineWidth: 1)
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(IslandButtonPressStyle())
                .help("Close options")
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.13)) {
                        isCloseHovered = hovering
                    }
                }

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Options")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                    Text("Island")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.44))
                }
            }
            .padding(.top, 4)

            VStack(spacing: 6) {
                ForEach(IslandOptionsTab.allCases) { tab in
                    OptionsSidebarButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.easeOut(duration: 0.16)) {
                            selectedTab = tab
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.88)) {
                    store.resetAppearance()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .bold))
                    Text("Reset")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(isResetHovered ? 0.11 : 0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(isResetHovered ? 0.15 : 0.10), lineWidth: 1)
                )
            }
            .buttonStyle(IslandButtonPressStyle())
            .help("Reset options")
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.13)) {
                    isResetHovered = hovering
                }
            }
        }
        .padding(22)
        .frame(width: 220)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.18))
    }

    private var activePanel: some View {
        ZStack(alignment: .topLeading) {
            switch selectedTab {
            case .appearance:
                appearancePanel
                    .transition(panelTransition)
            case .home:
                homePanel
                    .transition(panelTransition)
            case .behavior:
                behaviorPanel
                    .transition(panelTransition)
            case .weather:
                weatherPanel
                    .transition(panelTransition)
            case .sports:
                sportsPanel
                    .transition(panelTransition)
            }
        }
    }

    private var panelTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 6)),
            removal: .opacity
        )
    }

    private var homePanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            OptionsPanelHeader(
                title: "Home UI",
                detail: "First screen and two-UI mode",
                systemName: "rectangle.grid.2x2"
            )

            OptionsSection(title: "Mode") {
                OptionsSettingRow(title: "Layout mode") {
                    Picker("", selection: $store.layoutMode) {
                        ForEach(IslandLayoutMode.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                }
            }

            OptionsSection(title: "First UI") {
                HomeWidgetLayoutEditor(store: store)
            }

            OptionsSection(title: "Weather") {
                OptionsToggleRow(
                    systemName: "cloud.sun",
                    title: "Show weather",
                    detail: "Keep weather as a small first-UI widget",
                    isOn: $store.showHomeWeather
                )
            }

            Spacer(minLength: 0)
        }
    }

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            OptionsPanelHeader(
                title: "Appearance",
                detail: "Colors and island scale",
                systemName: "paintpalette"
            )

            OptionsSection(title: "Theme") {
                OptionsSettingRow(title: "Background") {
                    HStack(spacing: 11) {
                        ForEach(IslandBackgroundOption.allCases) { option in
                            ColorSwatchButton(
                                title: option.title,
                                color: option.color,
                                isSelected: store.backgroundOption == option
                            ) {
                                withAnimation(.easeOut(duration: 0.16)) {
                                    store.backgroundOption = option
                                }
                            }
                        }
                    }
                }

                OptionsSettingRow(title: "Text") {
                    HStack(spacing: 11) {
                        ForEach(IslandTextOption.allCases) { option in
                            ColorSwatchButton(
                                title: option.title,
                                color: option.color,
                                isSelected: store.textOption == option
                            ) {
                                withAnimation(.easeOut(duration: 0.16)) {
                                    store.textOption = option
                                }
                            }
                        }
                    }
                }
            }

            OptionsSection(title: "Layout") {
                OptionsSettingRow(title: "Expanded size") {
                    Picker("", selection: $store.expandedSizeOption) {
                        ForEach(IslandSizeOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var behaviorPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            OptionsPanelHeader(
                title: "Behavior",
                detail: "Interaction preferences",
                systemName: "cursorarrow.motionlines"
            )

            OptionsSection(title: "Pointer") {
                OptionsToggleRow(
                    systemName: "cursorarrow.rays",
                    title: "Hover expand",
                    detail: "Open the island from the compact view",
                    isOn: $store.autoExpandOnHover
                )
            }

            Spacer(minLength: 0)
        }
    }

    private var weatherPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            OptionsPanelHeader(
                title: "Weather",
                detail: "Manual city weather",
                systemName: "cloud.sun"
            )

            OptionsSection(title: "Location") {
                WeatherLocationSettingView(store: store)
            }

            Spacer(minLength: 0)
        }
    }

    private var sportsPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            OptionsPanelHeader(
                title: "Sports",
                detail: "Optional NBA scores",
                systemName: "basketball"
            )

            OptionsSection(title: "NBA") {
                NBAScoresSettingView(store: store)
            }

            Spacer(minLength: 0)
        }
    }
}

private enum IslandOptionsTab: String, CaseIterable, Identifiable {
    case appearance
    case home
    case behavior
    case weather
    case sports

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance:
            return "Appearance"
        case .home:
            return "Home UI"
        case .behavior:
            return "Behavior"
        case .weather:
            return "Weather"
        case .sports:
            return "Sports"
        }
    }

    var systemName: String {
        switch self {
        case .appearance:
            return "paintpalette"
        case .home:
            return "rectangle.grid.2x2"
        case .behavior:
            return "cursorarrow.motionlines"
        case .weather:
            return "cloud.sun"
        case .sports:
            return "basketball"
        }
    }
}

private struct OptionsSidebarButton: View {
    let tab: IslandOptionsTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: tab.systemName)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 22)

                Text(tab.title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))

                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.white.opacity(isSelected ? 0.96 : (isHovered ? 0.80 : 0.58)))
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(backgroundOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.12 : 0.0), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(IslandButtonPressStyle())
        .help(tab.title)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.13)) {
                isHovered = hovering
            }
        }
    }

    private var backgroundOpacity: CGFloat {
        if isSelected { return 0.11 }
        return isHovered ? 0.055 : 0.0
    }
}

private struct OptionsPanelHeader: View {
    let title: String
    let detail: String
    let systemName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                Text(detail)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.48))
            }

            Spacer(minLength: 0)
        }
    }
}

private struct OptionsSection<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .foregroundStyle(Color.white.opacity(0.42))
                .padding(.leading, 2)

            VStack(spacing: 10) {
                content()
            }
        }
    }
}

private struct OptionsSettingRow<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.66))
                .frame(width: 142, alignment: .leading)

            content()

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.052))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.085), lineWidth: 1)
        )
    }
}

private struct OptionsToggleRow: View {
    let systemName: String
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.86))
                Text(detail)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.46))
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(GreenSwitchToggleStyle())
                .fixedSize()
                .help(title)
        }
        .padding(16)
        .frame(minHeight: 76)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }
}

private struct WeatherLocationSettingView: View {
    @ObservedObject var store: IslandStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 17, weight: .bold))
                .frame(width: 42, height: 42)
                .foregroundStyle(Color.yellow.opacity(0.92), Color.white.opacity(0.62))
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("City or ZIP", text: $store.weatherLocationInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.black.opacity(0.24))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .onSubmit {
                            store.applyWeatherLocationFromInput()
                        }

                    OptionsInlineIconButton(
                        systemName: store.weatherStatus == .loading ? "arrow.clockwise" : "checkmark",
                        iconSize: 12,
                        baseOpacity: 0.10,
                        title: "Save weather city",
                        isEnabled: store.canApplyWeatherLocation
                    ) {
                        store.applyWeatherLocationFromInput()
                    }

                    OptionsInlineIconButton(
                        systemName: "xmark",
                        iconSize: 11,
                        baseOpacity: 0.07,
                        title: "Clear weather city",
                        isEnabled: !(store.weatherLocationInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.weatherInfo == nil)
                    ) {
                        store.clearWeatherLocation()
                    }
                }

                Text(store.weatherOptionsStatusText)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(Color.white.opacity(0.48))
            }
        }
        .padding(16)
        .frame(minHeight: 86)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }
}

private struct OptionsInlineIconButton: View {
    let systemName: String
    let iconSize: CGFloat
    let baseOpacity: CGFloat
    let title: String
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .black))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(isHovered && isEnabled ? baseOpacity + 0.06 : baseOpacity))
                )
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(IslandButtonPressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.38)
        .help(title)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.13)) {
                isHovered = hovering
            }
        }
    }
}

private struct NBAScoresSettingView: View {
    @ObservedObject var store: IslandStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "basketball.fill")
                .font(.system(size: 17, weight: .bold))
                .frame(width: 42, height: 42)
                .foregroundStyle(Color(red: 0.96, green: 0.42, blue: 0.18), Color.white.opacity(0.62))
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("NBA scores")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.86))
                Text(store.nbaOptionsStatusText)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $store.nbaScoresEnabled)
                .labelsHidden()
                .toggleStyle(GreenSwitchToggleStyle())
                .fixedSize()
                .help("Enable NBA scores")
        }
        .padding(16)
        .frame(minHeight: 76)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }
}

private struct HomeWidgetLayoutEditor: View {
    @ObservedObject var store: IslandStore
    @Namespace private var widgetNamespace
    @State private var draggingWidget: HomeWidget?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            orderedWidgetStrip
            widgetToggleRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var orderedWidgetStrip: some View {
        HStack(spacing: 8) {
            ForEach(store.visibleHomeWidgets) { widget in
                HomeWidgetDragTile(
                    widget: widget,
                    isDragging: draggingWidget == widget,
                    canRemove: store.canRemoveHomeWidget(widget)
                ) {
                    withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.88)) {
                        store.toggleHomeWidget(widget)
                    }
                }
                .matchedGeometryEffect(id: widget.id, in: widgetNamespace)
                .onDrag {
                    draggingWidget = widget
                    return NSItemProvider(object: widget.rawValue as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: HomeWidgetDropDelegate(
                        targetWidget: widget,
                        store: store,
                        draggingWidget: $draggingWidget
                    )
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                    removal: .scale(scale: 0.92).combined(with: .opacity)
                ))
            }
        }
        .padding(8)
        .frame(width: 504, height: 82, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .animation(.interactiveSpring(response: 0.30, dampingFraction: 0.82, blendDuration: 0.08), value: store.visibleHomeWidgets)
    }

    private var widgetToggleRow: some View {
        HStack(spacing: 8) {
            ForEach(HomeWidget.optionOrder) { widget in
                HomeWidgetToggleChip(
                    widget: widget,
                    isSelected: store.isHomeWidgetSelected(widget),
                    canRemove: store.canRemoveHomeWidget(widget)
                ) {
                    withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.88)) {
                        store.toggleHomeWidget(widget)
                    }
                }
            }
        }
    }
}

private struct HomeWidgetDragTile: View {
    let widget: HomeWidget
    let isDragging: Bool
    let canRemove: Bool
    let removeAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 7) {
                Image(systemName: widget.systemName)
                    .font(.system(size: 20, weight: .heavy))
                    .frame(height: 24)
                    .foregroundStyle(tileIconColor)

                Text(widget.shortTitle)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if canRemove {
                Button(action: removeAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .black))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.black.opacity(0.28)))
                }
                .buttonStyle(IslandButtonPressStyle())
                .help("Hide \(widget.title)")
                .padding(7)
            }
        }
        .frame(width: tileWidth, height: 66)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isDragging ? 0.18 : 0.105))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(isDragging ? 0.34 : 0.12), lineWidth: 1)
        )
        .scaleEffect(isDragging ? 0.96 : 1)
        .opacity(isDragging ? 0.72 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86), value: isDragging)
    }

    private var tileIconColor: Color {
        switch widget {
        case .appleMusic:
            return Color(red: 1.00, green: 0.48, blue: 0.62).opacity(0.96)
        case .calendar:
            return Color(red: 0.25, green: 0.70, blue: 1.00).opacity(0.96)
        case .nbaScores:
            return Color(red: 0.96, green: 0.42, blue: 0.18).opacity(0.96)
        }
    }

    private var tileWidth: CGFloat {
        switch widget {
        case .appleMusic:
            return 154
        case .calendar:
            return 154
        case .nbaScores:
            return 118
        }
    }
}

private struct HomeWidgetToggleChip: View {
    let widget: HomeWidget
    let isSelected: Bool
    let canRemove: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(widget.shortTitle)
                    .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.white.opacity(isSelected ? 0.92 : (isHovered ? 0.76 : 0.54)))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                Capsule()
                    .fill(Color.white.opacity(isSelected ? 0.105 : (isHovered ? 0.075 : 0.045)))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isSelected ? 0.18 : (isHovered ? 0.12 : 0.07)), lineWidth: 1)
            )
        }
        .buttonStyle(IslandButtonPressStyle())
        .disabled(isSelected && !canRemove)
        .opacity(isSelected && !canRemove ? 0.62 : 1)
        .help(helpText)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.13)) {
                isHovered = hovering
            }
        }
    }

    private var helpText: String {
        if isSelected && !canRemove {
            return "At least one first-UI widget is required"
        }

        return isSelected ? "Hide \(widget.title)" : "Show \(widget.title)"
    }
}

private struct HomeWidgetDropDelegate: DropDelegate {
    let targetWidget: HomeWidget
    let store: IslandStore
    @Binding var draggingWidget: HomeWidget?

    func dropEntered(info: DropInfo) {
        guard let draggingWidget, draggingWidget != targetWidget else { return }

        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.82, blendDuration: 0.06)) {
            store.moveHomeWidget(draggingWidget, around: targetWidget)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingWidget = nil
        return true
    }
}

private struct ColorSwatchButton: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)

                if isSelected {
                    Circle()
                        .fill(Color.black.opacity(0.28))
                        .frame(width: 18, height: 18)

                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color.white)
                }
            }
            .frame(width: 32, height: 32)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(ringOpacity), lineWidth: isSelected ? 1.6 : 1)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.30 : 0.0), radius: 5, x: 0, y: 2)
            .scaleEffect(isHovered ? 1.10 : 1.0)
            .contentShape(Circle())
        }
        .buttonStyle(IslandButtonPressStyle())
        .help(title)
        .onHover { hovering in
            withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.80)) {
                isHovered = hovering
            }
        }
    }

    private var ringOpacity: CGFloat {
        if isSelected { return 0.82 }
        return isHovered ? 0.50 : 0.24
    }
}

private struct CompactIslandView: View {
    @ObservedObject var store: IslandStore
    @Environment(\.islandTextColor) private var islandTextColor
    @State private var chargingFillFraction: CGFloat = 0
    @State private var systemControlLevel: CGFloat = 0

    private var showsChargingPulse: Bool {
        !store.isDragTargeted && !showsSystemControlFeedback && store.chargingBannerID != nil
    }

    private var showsAirPodsIcon: Bool {
        !store.isDragTargeted && !showsSystemControlFeedback && !showsChargingPulse && store.airPodsBannerName != nil
    }

    private var showsSystemControlFeedback: Bool {
        !store.isDragTargeted && store.systemControlFeedback != nil
    }

    var body: some View {
        Group {
            if store.isDragTargeted {
                dragTargetContent
            } else {
                ZStack {
                    normalCompactContent
                        .opacity(showsChargingPulse || showsAirPodsIcon || showsSystemControlFeedback ? 0 : 1)
                        .scaleEffect(showsChargingPulse || showsAirPodsIcon || showsSystemControlFeedback ? 0.98 : 1.0)

                    airPodsCompactContent
                        .opacity(showsAirPodsIcon ? 1 : 0)
                        .scaleEffect(showsAirPodsIcon ? 1.0 : 0.96)

                    chargingCompactContent
                        .opacity(showsChargingPulse ? 1 : 0)
                        .scaleEffect(showsChargingPulse ? 1.0 : 0.96)

                    systemControlCompactContent
                        .opacity(showsSystemControlFeedback ? 1 : 0)
                        .scaleEffect(showsSystemControlFeedback ? 1.0 : 0.96)
                }
                .animation(.easeInOut(duration: 0.18), value: showsAirPodsIcon)
                .animation(.easeInOut(duration: 0.16), value: showsChargingPulse)
                .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.86), value: showsSystemControlFeedback)
            }
        }
        .foregroundStyle(islandTextColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: store.chargingBannerID) { _ in
            handleChargingBannerChange()
        }
        .onChange(of: store.systemControlFeedback) { _ in
            handleSystemControlFeedbackChange()
        }
        .onAppear {
            handleChargingBannerChange()
            handleSystemControlFeedbackChange()
        }
    }

    private var dragTargetContent: some View {
        HStack(spacing: 0) {
            VStack(spacing: 5) {
                Image(systemName: store.isClipboardPaused ? "pause.circle.fill" : "doc.on.clipboard.fill")
                    .font(.system(size: 21, weight: .semibold))

                Text("Clipboard")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Text("\(store.clipboardEntries.count)/5")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(islandTextColor.opacity(0.48))
                    .lineLimit(1)
            }
            .frame(width: 96)
            .frame(maxHeight: .infinity)

            Rectangle()
                .fill(islandTextColor.opacity(0.11))
                .frame(width: 1)
                .padding(.vertical, 10)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(islandTextColor.opacity(0.075))
                        .frame(width: 40, height: 40)

                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 22, weight: .semibold))
                }
                .frame(width: 52, height: 64)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Drop anywhere")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    Text("Files land in the shelf")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(islandTextColor.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                MiniIslandSignal(systemName: "doc", count: store.files.count)
            }
            .padding(.leading, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var normalCompactContent: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var airPodsCompactContent: some View {
        HStack(spacing: 0) {
            Image(systemName: "airpodspro")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 35, height: 20, alignment: .leading)

            Spacer(minLength: IslandMetrics.notchCoreWidth)

            Color.clear
                .frame(width: 35, height: 20)
        }
    }

    private var chargingCompactContent: some View {
        let green = Color(red: 0.300, green: 1.000, blue: 0.420)
        let targetWidth = max(3, chargingFillFraction * 54)

        return HStack(spacing: 0) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.90),
                            green,
                            Color(red: 0.080, green: 0.850, blue: 0.290)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: green.opacity(0.72), radius: 5, x: 0, y: 0)
                .shadow(color: green.opacity(0.26), radius: 10, x: 0, y: 0)
                .frame(width: 46, height: 20, alignment: .leading)
                .offset(y: -2)

            Spacer(minLength: IslandMetrics.notchCoreWidth)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(green.opacity(0.14))
                    .frame(width: 54, height: 6)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                green.opacity(0.45),
                                green,
                                Color.white.opacity(0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: targetWidth, height: 6)
                    .shadow(color: green.opacity(0.58), radius: 6)
            }
            .frame(width: 54, height: 20, alignment: .leading)
        }
    }

    @ViewBuilder
    private var systemControlCompactContent: some View {
        if let feedback = store.systemControlFeedback {
            let tint = feedback.kind.tint
            let iconSize: CGFloat = feedback.kind == .brightness ? 11.5 : 13
            let barWidth: CGFloat = 64
            let targetWidth = max(3, systemControlLevel * barWidth)

            HStack(spacing: 0) {
                Image(systemName: feedback.kind.systemName(level: feedback.level))
                    .font(.system(size: iconSize, weight: .black))
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.14), value: feedback.kind.systemName(level: feedback.level))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.94),
                            tint,
                            tint.opacity(0.70)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: tint.opacity(0.55), radius: 6, x: 0, y: 0)
                .frame(width: 46, height: 22, alignment: .leading)
                .offset(y: -1)

                Spacer(minLength: IslandMetrics.notchCoreWidth)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tint.opacity(0.14))
                        .frame(width: barWidth, height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.52),
                                    tint,
                                    Color.white.opacity(0.82)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: targetWidth, height: 6)
                        .shadow(color: tint.opacity(0.48), radius: 5)
                }
                .frame(width: barWidth, height: 22, alignment: .leading)
            }
        }
    }

    private func handleChargingBannerChange() {
        guard store.chargingBannerID != nil else {
            chargingFillFraction = 0
            return
        }

        chargingFillFraction = 0
        let targetPercent = store.chargingBatteryPercent ?? 100
        let targetFraction = CGFloat(min(max(targetPercent, 0), 100)) / 100

        withAnimation(.easeOut(duration: 0.95)) {
            chargingFillFraction = targetFraction
        }
    }

    private func handleSystemControlFeedbackChange() {
        guard let feedback = store.systemControlFeedback else { return }

        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.88)) {
            systemControlLevel = feedback.level
        }
    }
}

private struct ExpandedIslandView: View {
    @ObservedObject var store: IslandStore
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch store.islandMode {
            case .player:
                if store.layoutMode == .customTwoModes {
                    CustomHomeDashboardView(store: store)
                        .transition(modeTransition)
                } else {
                    PlayerDashboardView(store: store)
                        .transition(modeTransition)
                }
            case .nba:
                NBADashboardView(store: store)
                    .transition(modeTransition)
            case .workspace:
                workspaceContent
                    .transition(modeTransition)
            }

            modeSelectorOverlay
        }
        .foregroundStyle(islandTextColor)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.90, blendDuration: 0.08), value: store.islandMode)
    }

    private var modeTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.985, anchor: .top))
    }

    private var workspaceContent: some View {
        let contentSize = workspaceContentSize

        return ZStack(alignment: .topLeading) {
            HStack(alignment: .top, spacing: 12) {
                ClipboardDock(store: store)
                    .frame(width: workspaceClipboardWidth, height: contentSize.height)

                FileShelfGallery(store: store)
                    .frame(
                        width: contentSize.width - workspaceClipboardWidth - 12,
                        height: contentSize.height
                    )
            }
            .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
    }

    private var workspaceContentSize: CGSize {
        let expandedSize = store.expandedSize(for: .workspace)
        return CGSize(width: expandedSize.width - 32, height: expandedSize.height - 22)
    }

    private var workspaceClipboardWidth: CGFloat {
        store.expandedSizeOption == .large ? 224 : 196
    }

    private var modeSelector: some View {
        HStack(spacing: 1) {
            ForEach(store.visibleModes, id: \.self) { mode in
                ModeSelectorButton(
                    systemName: store.modeSystemName(for: mode),
                    title: store.modeTitle(for: mode),
                    isSelected: store.islandMode == mode
                ) {
                    withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.88)) {
                        switch mode {
                        case .player:
                            store.showPlayerMode()
                        case .nba:
                            store.showNBAMode()
                        case .workspace:
                            store.showWorkspaceMode()
                        }
                    }
                }
            }
        }
        .padding(2)
        .frame(width: CGFloat(store.visibleModes.count) * 20 + 2, height: 20)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.82))
        )
        .overlay {
            Capsule()
                .stroke(islandTextColor.opacity(0.18), lineWidth: 1)
        }
    }

    private var modeSelectorOverlay: some View {
        modeSelector
            .offset(x: 5, y: -8)
            .zIndex(4)
    }

    private var controls: some View {
        HStack(spacing: 7) {
            Text(store.isClipboardPaused ? "Resume" : "Pause")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .frame(width: 44, alignment: .trailing)

            Toggle("", isOn: $store.isClipboardPaused)
                .labelsHidden()
                .toggleStyle(GreenSwitchToggleStyle())
                .fixedSize()

            IconButton(systemName: "trash", title: "Clear clipboard history") {
                store.clearClipboardHistory()
            }
            .disabled(store.clipboardEntries.isEmpty)
        }
        .frame(width: 134, alignment: .trailing)
    }
}

private struct ModeSelectorButton: View {
    let systemName: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 8, weight: .black))
                .frame(width: 16, height: 16)
                .foregroundStyle(islandTextColor.opacity(isSelected ? 0.96 : (isHovered ? 0.78 : 0.48)))
                .background {
                    if isSelected || isHovered {
                        Circle()
                            .fill(islandTextColor.opacity(isSelected ? 0.14 : 0.08))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(IslandButtonPressStyle())
        .help(title)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.13)) {
                isHovered = hovering
            }
        }
    }
}

private enum NBADashboardSizing {
    case mode
    case home
}

private struct NBADashboardView: View {
    @ObservedObject var store: IslandStore
    var sizing: NBADashboardSizing = .mode
    var reservesWeatherSpace = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        let expandedSize = sizing == .home ? store.expandedSize(for: .player) : store.expandedSize(for: .nba)
        let contentHeight = expandedSize.height - 26

        VStack(alignment: .leading, spacing: 8) {
            topBar
                .padding(.leading, 98)
                .padding(.trailing, reservesWeatherSpace ? 76 : 4)

            dashboardContent
        }
        .frame(width: expandedSize.width - 28, height: contentHeight, alignment: .topLeading)
        .padding(.top, sizing == .home ? 16 : 1)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("NBA Today")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .lineLimit(1)

                Text(updateText)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(islandTextColor.opacity(0.48))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            NBAStatusPill(statusText: pillText, isLive: store.nbaScoreboard?.hasLiveGame == true)

            IconButton(systemName: "arrow.clockwise", title: "Refresh NBA scores") {
                store.refreshNBAFromUserAction()
            }
            .disabled(!store.nbaScoresEnabled || store.nbaScoresStatus == .loading)
        }
        .frame(height: 32)
    }

    @ViewBuilder
    private var dashboardContent: some View {
        if !store.nbaScoresEnabled {
            NBAEmptyStateView(
                systemName: "basketball",
                title: "NBA scores off",
                detail: "Enable the free no-key scoreboard",
                buttonTitle: "Enable",
                action: store.enableNBAScores
            )
        } else if store.nbaScoreboard == nil && store.nbaScoresStatus == .loading {
            NBALoadingView()
        } else if let scoreboard = store.nbaScoreboard, scoreboard.games.isEmpty {
            NBAEmptyStateView(
                systemName: "calendar.badge.clock",
                title: "No NBA games today",
                detail: "Check back on the next slate",
                buttonTitle: nil,
                action: nil
            )
        } else if store.nbaGames.isEmpty {
            NBAEmptyStateView(
                systemName: "wifi.exclamationmark",
                title: "Scores unavailable",
                detail: "No cached scores yet",
                buttonTitle: "Retry",
                action: store.refreshNBAFromUserAction
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if case .failed = store.nbaScoresStatus {
                    HStack(spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Scores unavailable")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Color.yellow.opacity(0.84))
                    .frame(height: 13)
                }

                gameStrip
                    .frame(height: 68)

                if store.selectedNBAGame != nil {
                    NBABoxScorePanel(store: store)
                        .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
                }
            }
        }
    }

    private var gameStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.nbaGames) { game in
                    NBAGameCapsule(
                        game: game,
                        isSelected: store.selectedNBAGameID == game.id
                    ) {
                        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88)) {
                            store.selectNBAGame(game)
                        }
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private var updateText: String {
        if let updatedAt = store.nbaScoreboard?.updatedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Updated \(formatter.string(from: updatedAt))"
        }

        return store.nbaOptionsStatusText
    }

    private var pillText: String {
        if store.nbaScoreboard?.hasLiveGame == true {
            return "Live"
        }

        if let scoreboard = store.nbaScoreboard, !scoreboard.games.isEmpty {
            return "Today"
        }

        switch store.nbaScoresStatus {
        case .disabled:
            return "Off"
        case .loading:
            return "Loading"
        case .failed:
            return "Error"
        case .idle, .available:
            return "Ready"
        }
    }
}

private struct NBAStatusPill: View {
    let statusText: String
    let isLive: Bool
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isLive ? Color.green : Color.white.opacity(0.42))
                .frame(width: 6, height: 6)
                .background {
                    if isLive {
                        Circle()
                            .stroke(Color.green.opacity(isPulsing ? 0.0 : 0.55), lineWidth: 1.4)
                            .scaleEffect(isPulsing ? 2.6 : 1.0)
                    }
                }
                .onAppear(perform: syncPulse)
                .onChange(of: isLive) { _ in
                    syncPulse()
                }

            Text(statusText)
                .font(.system(size: 10.5, weight: .black, design: .rounded))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(
            Capsule()
                .fill(Color.white.opacity(isLive ? 0.10 : 0.065))
        )
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(isLive ? 0.16 : 0.09), lineWidth: 1)
        }
    }

    private func syncPulse() {
        guard isLive else {
            isPulsing = false
            return
        }

        isPulsing = false
        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
            isPulsing = true
        }
    }
}

private struct NBAGameCapsule: View {
    let game: NBAGameSummary
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 8) {
                    teamBlock(team: game.awayTeam)
                    Text("@")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(islandTextColor.opacity(0.32))
                        .padding(.top, 3)
                    teamBlock(team: game.homeTeam)
                }

                HStack(spacing: 5) {
                    Text(game.displayStatus)
                        .font(.system(size: 10.2, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    if let seriesText = game.seriesText {
                        Text(seriesText)
                            .font(.system(size: 9.2, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(islandTextColor.opacity(0.46))
                    }
                }
            }
            .padding(.horizontal, 11)
            .frame(width: 166, height: 64, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(fillOpacity))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? 1.2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(IslandButtonPressStyle())
        .help("\(game.awayTeam.tricode) at \(game.homeTeam.tricode)")
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
    }

    private var fillOpacity: CGFloat {
        if isSelected { return 0.13 }
        return isHovered ? 0.09 : 0.055
    }

    private func teamBlock(team: NBATeamSummary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            teamLine(team: team)
            Text(team.name)
                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .foregroundStyle(islandTextColor.opacity(0.56))
                .frame(width: 58, height: 18, alignment: .topLeading)
                .accessibilityLabel("\(team.city) \(team.name)")
        }
        .frame(width: 58, alignment: .leading)
    }

    private func teamLine(team: NBATeamSummary) -> some View {
        HStack(spacing: 4) {
            Text(team.tricode)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .lineLimit(1)
            Text(game.hasScore ? "\(team.score)" : "--")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(islandTextColor.opacity(game.hasScore ? 0.92 : 0.36))
        }
    }

    private var borderColor: Color {
        if isSelected {
            return Color(red: 0.96, green: 0.42, blue: 0.18).opacity(0.70)
        }

        return islandTextColor.opacity(isHovered ? 0.16 : 0.09)
    }
}

private struct NBABoxScorePanel: View {
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

private struct NBABoxSideButton: View {
    let title: String
    let side: NBABoxScoreSide
    @Binding var selectedSide: NBABoxScoreSide
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.14)) {
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
        }
        .buttonStyle(IslandButtonPressStyle())
        .help(title)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.13)) {
                isHovered = hovering
            }
        }
    }

    private var fillOpacity: CGFloat {
        if selectedSide == side { return 0.16 }
        return isHovered ? 0.10 : 0.06
    }
}

private struct NBAStatHeaderRow: View {
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

private struct NBAPlayerStatRow: View {
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

private struct NBAEmptyStateView: View {
    let systemName: String
    let title: String
    let detail: String
    let buttonTitle: String?
    let action: (() -> Void)?
    @State private var isButtonHovered = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .frame(width: 48, height: 48)
                .foregroundStyle(Color(red: 0.96, green: 0.42, blue: 0.18).opacity(0.92))
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(islandTextColor.opacity(0.48))
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            if let buttonTitle, let action {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .frame(width: 74, height: 32)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(isButtonHovered ? 0.18 : 0.12))
                        )
                }
                .buttonStyle(IslandButtonPressStyle())
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.13)) {
                        isButtonHovered = hovering
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
    }
}

private struct NBALoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    NBASkeletonBlock(width: 150, height: 48)
                }
            }

            NBASkeletonBlock(width: nil, height: 64)
        }
        .padding(.top, 3)
    }
}

private struct NBAPlayerRowsLoadingView: View {
    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { _ in
                NBASkeletonBlock(width: nil, height: 14)
            }
        }
        .padding(.top, 2)
    }
}

private struct NBASkeletonBlock: View {
    let width: CGFloat?
    let height: CGFloat
    @State private var isShimmering = false

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color.white.opacity(0.055))
            .overlay {
                GeometryReader { proxy in
                    let bandWidth = max(proxy.size.width * 0.55, 40)

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.085),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: bandWidth)
                    .offset(x: isShimmering ? proxy.size.width : -bandWidth)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                    isShimmering = true
                }
            }
    }
}

private struct NBAInlineMessage: View {
    let systemName: String
    let text: String
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(islandTextColor.opacity(0.50))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct CustomHomeDashboardView: View {
    @ObservedObject var store: IslandStore

    var body: some View {
        let widgets = store.visibleHomeWidgets

        ZStack(alignment: .topTrailing) {
            if widgets == [.nbaScores] {
                NBADashboardView(
                    store: store,
                    sizing: .home,
                    reservesWeatherSpace: store.showHomeWeather
                )
            } else {
                widgetGrid(widgets)
            }

            if store.showHomeWeather {
                WeatherMiniWidgetView(store: store)
                    .padding(.top, 1)
                    .padding(.trailing, 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
            }
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        .animation(.interactiveSpring(response: 0.30, dampingFraction: 0.90, blendDuration: 0.08), value: store.homeWidgets)
        .animation(.easeOut(duration: 0.16), value: store.showHomeWeather)
    }

    private var contentSize: CGSize {
        let expandedSize = store.expandedSize(for: .player)
        return CGSize(width: expandedSize.width - 28, height: expandedSize.height - 25)
    }

    private func widgetGrid(_ widgets: [HomeWidget]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(widgets.enumerated()), id: \.element) { index, widget in
                if index > 0 {
                    HomeWidgetDivider()
                        .frame(height: dividerHeight(for: widgets.count))
                }

                HomeWidgetPanel(
                    store: store,
                    widget: widget,
                    index: index,
                    count: widgets.count,
                    reservesWeatherSpace: store.showHomeWeather && widgets.last == widget
                )
                .frame(width: widgetWidth(for: widgets.count), height: contentSize.height)
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        .background(HomeFlowSurface())
    }

    private func widgetWidth(for count: Int) -> CGFloat {
        let spacing = CGFloat(max(0, count - 1))
        return (contentSize.width - spacing) / CGFloat(max(count, 1))
    }

    private func dividerHeight(for count: Int) -> CGFloat {
        count >= 3 ? contentSize.height - 28 : contentSize.height - 38
    }
}

private struct HomeWidgetPanel: View {
    @ObservedObject var store: IslandStore
    let widget: HomeWidget
    let index: Int
    let count: Int
    let reservesWeatherSpace: Bool
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        content
            .padding(panelPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch widget {
        case .appleMusic:
            NowPlayingCardView(store: store)
                .padding(.horizontal, count == 1 ? 16 : 4)
                .padding(.trailing, reservesWeatherSpace ? 58 : 0)
        case .calendar:
            CalendarWidgetView(
                store: store,
                showsWeather: false,
                reservesWeatherSpace: false
            )
        case .nbaScores:
            HomeNBAScoresWidget(store: store, reservesWeatherSpace: reservesWeatherSpace)
        }
    }

    private var panelPadding: EdgeInsets {
        if count == 1 {
            return EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
        }

        return EdgeInsets(
            top: topInset,
            leading: horizontalInset,
            bottom: count >= 3 ? 4 : 8,
            trailing: horizontalInset
        )
    }

    private var horizontalInset: CGFloat {
        count >= 3 ? 12 : 16
    }

    private var topInset: CGFloat {
        if count >= 3 {
            return 16
        }

        return 12
    }
}

private struct HomeFlowSurface: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.020),
                Color.white.opacity(0.006),
                Color.white.opacity(0.018)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .allowsHitTesting(false)
    }
}

private struct HomeWidgetDivider: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(0.09),
                Color.white.opacity(0.035),
                Color.white.opacity(0.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 1)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .allowsHitTesting(false)
    }
}

private struct HomeNBAScoresWidget: View {
    @ObservedObject var store: IslandStore
    let reservesWeatherSpace: Bool
    @State private var isMessageButtonHovered = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if !store.nbaScoresEnabled {
                compactMessage(
                    systemName: "basketball",
                    title: "NBA scores off",
                    detail: "Enable the no-key scoreboard",
                    buttonTitle: "Enable",
                    action: store.enableNBAScores
                )
            } else if store.nbaScoreboard == nil && store.nbaScoresStatus == .loading {
                VStack(alignment: .leading, spacing: 7) {
                    NBASkeletonBlock(width: nil, height: 36)
                    NBASkeletonBlock(width: nil, height: 36)
                }
            } else if let scoreboard = store.nbaScoreboard, scoreboard.games.isEmpty {
                compactMessage(
                    systemName: "calendar.badge.clock",
                    title: "No games today",
                    detail: "Next slate will appear here",
                    buttonTitle: nil,
                    action: nil
                )
            } else if store.nbaGames.isEmpty {
                compactMessage(
                    systemName: "wifi.exclamationmark",
                    title: "Scores unavailable",
                    detail: "No cached scores yet",
                    buttonTitle: "Retry",
                    action: store.refreshNBAFromUserAction
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(store.nbaGames.prefix(2))) { game in
                        HomeNBAGameLine(game: game)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "basketball.fill")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color(red: 0.96, green: 0.42, blue: 0.18))

            VStack(alignment: .leading, spacing: 1) {
                Text("NBA Today")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                Text(updateText)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(islandTextColor.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            NBAStatusPill(statusText: pillText, isLive: store.nbaScoreboard?.hasLiveGame == true)
                .opacity(reservesWeatherSpace ? 0 : 1)

            if reservesWeatherSpace {
                Color.clear.frame(width: 60, height: 1)
            }
        }
        .frame(height: 32)
    }

    private func compactMessage(
        systemName: String,
        title: String,
        detail: String,
        buttonTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(islandTextColor.opacity(0.46))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if let buttonTitle, let action {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Capsule().fill(Color.white.opacity(isMessageButtonHovered ? 0.17 : 0.11)))
                }
                .buttonStyle(IslandButtonPressStyle())
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.13)) {
                        isMessageButtonHovered = hovering
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    }

    private var updateText: String {
        if let updatedAt = store.nbaScoreboard?.updatedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "Updated \(formatter.string(from: updatedAt))"
        }

        return store.nbaOptionsStatusText
    }

    private var pillText: String {
        if store.nbaScoreboard?.hasLiveGame == true {
            return "Live"
        }

        if let scoreboard = store.nbaScoreboard, !scoreboard.games.isEmpty {
            return "Today"
        }

        switch store.nbaScoresStatus {
        case .disabled:
            return "Off"
        case .loading:
            return "Loading"
        case .failed:
            return "Error"
        case .idle, .available:
            return "Ready"
        }
    }
}

private struct HomeNBAGameLine: View {
    let game: NBAGameSummary
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 8) {
            teamText(game.awayTeam)
            Text("@")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(islandTextColor.opacity(0.34))
            teamText(game.homeTeam)

            Spacer(minLength: 6)

            Text(game.displayStatus)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(islandTextColor.opacity(0.075), lineWidth: 1)
        }
    }

    private func teamText(_ team: NBATeamSummary) -> some View {
        HStack(spacing: 4) {
            Text(team.tricode)
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                .lineLimit(1)
            Text(game.hasScore ? "\(team.score)" : "--")
                .font(.system(size: 11.5, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(islandTextColor.opacity(game.hasScore ? 0.92 : 0.36))
                .lineLimit(1)
        }
        .frame(width: 56, alignment: .leading)
    }

    private var statusColor: Color {
        game.status.isLive ? Color.green.opacity(0.92) : islandTextColor.opacity(0.54)
    }
}

private struct PlayerDashboardView: View {
    @ObservedObject var store: IslandStore

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            NowPlayingCardView(store: store)
                .frame(width: nowPlayingWidth)
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(.leading, 24)
                .padding(.trailing, nowPlayingTrailingClearance)

            PlayerCalendarDivider()

            CalendarWidgetView(store: store, showsWeather: store.showHomeWeather)
                .padding(.leading, 14)
                .padding(.trailing, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var nowPlayingWidth: CGFloat {
        store.expandedSizeOption == .large ? 344 : 286
    }

    private var nowPlayingTrailingClearance: CGFloat {
        store.expandedSizeOption == .large ? 24 : 18
    }
}

private struct NowPlayingCardView: View {
    @ObservedObject var store: IslandStore
    @Environment(\.islandTextColor) private var islandTextColor

    private var info: NowPlayingInfo {
        store.nowPlaying
    }

    private var titleFontSize: CGFloat {
        info.hasContent ? 14 : 12.2
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            NowPlayingArtworkView(artworkImage: info.artwork)

            VStack(alignment: .leading, spacing: 4) {
                Text(notchSafeTitle)
                    .font(.system(size: titleFontSize, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                    .allowsTightening(true)
                    .truncationMode(.tail)
                    .foregroundStyle(islandTextColor)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.22), value: notchSafeTitle)
                    .frame(maxWidth: titleMaxWidth, alignment: .leading)
                    .padding(.top, info.hasContent ? 0 : 3)

                Text(info.displayArtist)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(islandTextColor.opacity(0.82))
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.22), value: info.displayArtist)

                HStack(spacing: 5) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 8, weight: .bold))
                    Text(info.detailLine)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.22), value: info.detailLine)
                }
                .foregroundStyle(islandTextColor.opacity(0.58))
                .padding(.top, 1)

                if info.progressFraction != nil {
                    progressRow
                        .padding(.top, 3)
                    Spacer(minLength: 1)
                } else {
                    Spacer(minLength: 2)
                }

                HStack(spacing: 9) {
                    MediaControlButton(
                        systemName: "backward.fill",
                        title: "Previous",
                        isEnabled: info.controls.previous && info.hasContent,
                        action: store.playPreviousTrack
                    )

                    MediaControlButton(
                        systemName: info.playbackState.isPlaying ? "pause.fill" : "play.fill",
                        title: info.playbackState.isPlaying ? "Pause" : "Play",
                        isEnabled: info.controls.playPause && info.hasContent,
                        isPrimary: true,
                        action: store.togglePlayPause
                    )

                    MediaControlButton(
                        systemName: "forward.fill",
                        title: "Next",
                        isEnabled: info.controls.next && info.hasContent,
                        action: store.playNextTrack
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 94, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(.easeOut(duration: 0.18), value: info.progressFraction != nil)
    }

    private var progressRow: some View {
        let fraction = CGFloat(info.progressFraction ?? 0)

        return HStack(spacing: 6) {
            Text(info.positionText ?? "0:00")
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(islandTextColor.opacity(0.52))
                .lineLimit(1)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(islandTextColor.opacity(0.16))

                    Capsule()
                        .fill(islandTextColor.opacity(0.85))
                        .frame(width: max(2.5, proxy.size.width * fraction))
                }
            }
            .frame(height: 3)
            .animation(.linear(duration: 0.85), value: fraction)

            Text(info.durationText ?? "--:--")
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(islandTextColor.opacity(0.52))
                .lineLimit(1)
        }
        .frame(height: 9)
    }

    private var titleMaxWidth: CGFloat {
        store.expandedSizeOption == .large ? 210 : 132
    }

    private var notchSafeTitle: String {
        guard info.hasContent else {
            return info.displayTitle
        }

        let title = info.displayTitle.uppercased()
        let featureMarkers = [" (FEAT", " FEAT.", " FEAT ", " (FT", " FT.", " FT "]

        for marker in featureMarkers {
            if let range = title.range(of: marker) {
                return title[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
            }
        }

        let words = title.split(separator: " ")
        if words.count >= 4 {
            return words.prefix(2).joined(separator: " ") + "..."
        }

        if title.count > maxTitleCharacters {
            let prefix = title.prefix(maxTitleCharacters).trimmingCharacters(in: .whitespacesAndNewlines)
            return prefix + "..."
        }

        return title
    }

    private var maxTitleCharacters: Int {
        store.expandedSizeOption == .large ? 26 : 18
    }
}

private struct PlayerCalendarDivider: View {
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        LinearGradient(
            colors: [
                islandTextColor.opacity(0.0),
                islandTextColor.opacity(0.18),
                islandTextColor.opacity(0.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 1, height: 88)
    }
}

private struct CalendarWidgetView: View {
    @ObservedObject var store: IslandStore
    var showsWeather = true
    var reservesWeatherSpace = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60.0)) { context in
            let model = CalendarStripModel(date: context.date)

            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(model.monthTitle)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.80)
                            .foregroundStyle(islandTextColor)
                            .frame(width: 50, alignment: .leading)

                        HStack(spacing: 3) {
                            ForEach(model.days) { day in
                                CalendarDayPill(day: day)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, showsWeather || reservesWeatherSpace ? 66 : 8)
                    }
                    .padding(.top, 7)

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 24, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(islandTextColor.opacity(0.07))
                            )

                        Text("Nothing for today")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .foregroundStyle(islandTextColor.opacity(0.54))
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                if showsWeather {
                    WeatherMiniWidgetView(store: store)
                        .offset(x: 4, y: -10)
                }
            }
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

private struct WeatherMiniWidgetView: View {
    @ObservedObject var store: IslandStore
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
                .frame(width: 21, height: 21)

            Text(temperatureText)
                .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .foregroundStyle(textColor)
        }
        .frame(width: 62, height: 26, alignment: .trailing)
        .contentShape(Rectangle())
        .help(helpText)
    }

    private var iconName: String {
        if store.weatherStatus == .loading && store.weatherInfo == nil {
            return "cloud.sun"
        }

        return store.weatherInfo?.systemName ?? "cloud.sun"
    }

    private var temperatureText: String {
        store.weatherInfo?.temperatureText ?? "--°"
    }

    private var textColor: Color {
        store.weatherInfo == nil ? islandTextColor.opacity(0.42) : islandTextColor.opacity(0.90)
    }

    private var iconColor: Color {
        guard let info = store.weatherInfo else {
            return islandTextColor.opacity(0.42)
        }

        switch info.weatherCode {
        case 0:
            return info.isDay ? Color.yellow.opacity(0.96) : Color(red: 0.76, green: 0.84, blue: 1.00)
        case 1, 2:
            return info.isDay ? Color.yellow.opacity(0.84) : Color(red: 0.70, green: 0.78, blue: 0.96)
        case 45, 48:
            return Color.gray.opacity(0.88)
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99:
            return Color(red: 0.42, green: 0.68, blue: 1.00)
        case 71, 73, 75, 77, 85, 86:
            return Color(red: 0.78, green: 0.88, blue: 1.00)
        default:
            return islandTextColor.opacity(0.64)
        }
    }

    private var helpText: String {
        switch store.weatherStatus {
        case .notConfigured:
            return "Set weather city in Options"
        case .loading:
            return "Checking weather"
        case .available:
            guard let info = store.weatherInfo else { return "Weather" }
            return "\(info.locationName) \(info.temperatureText)"
        case .failed:
            return store.weatherInfo == nil ? "Weather unavailable" : "Weather update failed"
        }
    }
}

private struct CalendarDayPill: View {
    let day: CalendarStripDay
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        VStack(spacing: 2) {
            Text(day.weekday)
                .font(.system(size: day.isToday ? 9 : 8.5, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Text(day.dayNumber)
                .font(.system(size: day.isToday ? 17 : 14, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(foregroundColor)
        .frame(width: day.isToday ? 35 : 25, height: 43)
        .background {
            if day.isToday {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.00, green: 0.53, blue: 0.94).opacity(0.20))
            }
        }
        .overlay {
            if day.isToday {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.10, green: 0.67, blue: 1.00).opacity(0.72), lineWidth: 1)
            }
        }
    }

    private var foregroundColor: Color {
        if day.isToday {
            return Color(red: 0.20, green: 0.73, blue: 1.00)
        }

        if day.isWeekend {
            return Color(red: 1.00, green: 0.45, blue: 0.38).opacity(0.56)
        }

        return islandTextColor.opacity(0.54)
    }
}

private struct CalendarStripModel {
    let monthTitle: String
    let days: [CalendarStripDay]

    init(date: Date) {
        let calendar = Calendar.current
        monthTitle = Self.formatted(date, format: "MMM")
        days = (-3...3).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else {
                return nil
            }

            let startOfDay = calendar.startOfDay(for: day)
            let weekdayIndex = calendar.component(.weekday, from: day)

            return CalendarStripDay(
                id: startOfDay.timeIntervalSinceReferenceDate,
                weekday: Self.formatted(day, format: "EEE").uppercased(),
                dayNumber: Self.formatted(day, format: "dd"),
                isToday: calendar.isDateInToday(day),
                isWeekend: weekdayIndex == 1 || weekdayIndex == 7
            )
        }
    }

    private static func formatted(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

private struct CalendarStripDay: Identifiable {
    let id: TimeInterval
    let weekday: String
    let dayNumber: String
    let isToday: Bool
    let isWeekend: Bool
}

private struct NowPlayingArtworkView: View {
    let artworkImage: NSImage?
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        artwork
            .frame(width: 76, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(islandTextColor.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.28), radius: 8, x: 0, y: 4)
            .frame(width: 84, height: 84)
            .animation(.easeInOut(duration: 0.30), value: artworkImage.map(ObjectIdentifier.init))
    }

    @ViewBuilder
    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            islandTextColor.opacity(0.14),
                            islandTextColor.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(islandTextColor.opacity(0.70))
                }

            if let artworkImage {
                Image(nsImage: artworkImage)
                    .resizable()
                    .scaledToFill()
                    .id(ObjectIdentifier(artworkImage))
                    .transition(.opacity)
            }
        }
    }
}

private struct MediaControlButton: View {
    let systemName: String
    let title: String
    let isEnabled: Bool
    var isPrimary = false
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: isPrimary ? 13 : 11, weight: .black))
                .frame(width: isPrimary ? 28 : 22, height: isPrimary ? 28 : 22)
                .foregroundStyle(islandTextColor.opacity(isEnabled ? (isHovered ? 1.0 : 0.95) : 0.30))
                .background {
                    Circle()
                        .fill(islandTextColor.opacity(backgroundOpacity))
                }
                .scaleEffect(isHovered && isEnabled ? 1.06 : 1.0)
                .contentShape(Circle())
        }
        .buttonStyle(IslandButtonPressStyle())
        .disabled(!isEnabled)
        .help(title)
        .onHover { hovering in
            withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.82)) {
                isHovered = hovering && isEnabled
            }
        }
    }

    private var backgroundOpacity: CGFloat {
        if isPrimary {
            guard isEnabled else { return 0.06 }
            return isHovered ? 0.20 : 0.13
        }

        return isHovered && isEnabled ? 0.10 : 0.0
    }
}

private struct ClipboardDock: View {
    @ObservedObject var store: IslandStore
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: store.isClipboardPaused ? "pause.circle.fill" : "doc.on.clipboard.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 17)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Clipboard")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    Text(store.isClipboardPaused ? "Paused" : "\(store.clipboardEntries.count)/5 clips")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(islandTextColor.opacity(0.44))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Toggle("", isOn: $store.isClipboardPaused)
                    .labelsHidden()
                    .toggleStyle(GreenSwitchToggleStyle())
                    .fixedSize()
                    .scaleEffect(0.76)
                    .frame(width: 28, height: 18)
                    .help(store.isClipboardPaused ? "Resume clipboard watching" : "Pause clipboard watching")

                IconButton(systemName: "trash", title: "Clear clipboard history") {
                    store.clearClipboardHistory()
                }
                .disabled(store.clipboardEntries.isEmpty)
            }
            .frame(height: 28)

            if store.clipboardEntries.isEmpty {
                ClipboardEmptyDock(isPaused: store.isClipboardPaused)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(store.clipboardEntries) { entry in
                            ClipboardDockItem(
                                entry: entry,
                                copy: { store.copyClipboardEntry(entry) },
                                inspect: { store.inspectClipboardEntry(entry) }
                            )
                        }
                    }
                    .padding(.bottom, 1)
                }
            }
        }
        .padding(.top, 28)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .popover(item: detailPopoverBinding, arrowEdge: .bottom) { entry in
            ClipboardDetailPopover(
                entry: entry,
                copy: { store.copyClipboardEntry(entry) },
                close: { store.closeClipboardDetail() },
                hoverChanged: { store.setClipboardDetailHovered($0) }
            )
        }
        .transaction { transaction in
            transaction.disablesAnimations = store.inspectedClipboardEntry == nil
        }
    }

    private var detailPopoverBinding: Binding<ClipboardEntry?> {
        Binding(
            get: { store.inspectedClipboardEntry },
            set: { entry in
                var transaction = Transaction()
                transaction.disablesAnimations = entry == nil

                withTransaction(transaction) {
                    store.setClipboardDetailFromPopover(entry)
                }
            }
        )
    }
}

private struct ClipboardEmptyDock: View {
    let isPaused: Bool
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(islandTextColor.opacity(0.075))
                    .frame(width: 44, height: 44)

                Image(systemName: isPaused ? "pause.circle" : "doc.on.clipboard")
                    .font(.system(size: 20, weight: .semibold))
            }
            .frame(width: 52, height: 52)

            Text(isPaused ? "Paused" : "Clipboard ready")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .lineLimit(1)

            Text(isPaused ? "Watching is off" : "Copied items surface here")
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .foregroundStyle(islandTextColor.opacity(0.36))
                .lineLimit(1)
        }
        .foregroundStyle(islandTextColor.opacity(0.56))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RadialGradient(
                colors: [
                    islandTextColor.opacity(0.050),
                    islandTextColor.opacity(0.018),
                    .clear
                ],
                center: .center,
                startRadius: 4,
                endRadius: 92
            )
        )
    }
}

private struct ClipboardDockItem: View {
    let entry: ClipboardEntry
    let copy: () -> Void
    let inspect: () -> Void
    @State private var isHovered = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 8) {
            Button(action: inspect) {
                HStack(spacing: 8) {
                    ClipboardThumb(entry: entry)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.dockTitle)
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text(entry.kindLabel)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(islandTextColor.opacity(0.46))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(IslandButtonPressStyle())
            .help(entry.kind == .image ? "Preview image" : "Show full copied text")

            IconButton(systemName: "doc.on.doc", title: "Copy back to clipboard", action: copy)
                .frame(width: 20)
        }
        .padding(.leading, 8)
        .padding(.trailing, 5)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(islandTextColor.opacity(isHovered ? 0.085 : 0.042))
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.13)) {
                isHovered = hovering
            }
        }
    }
}

private struct ClipboardThumb: View {
    let entry: ClipboardEntry
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(islandTextColor.opacity(0.10))

            switch entry.kind {
            case .image:
                if let image = entry.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 10, weight: .semibold))
                }
            case .link:
                Image(systemName: "link")
                    .font(.system(size: 10, weight: .semibold))
            case .text:
                Image(systemName: "text.alignleft")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(islandTextColor.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct FileShelfGallery: View {
    @ObservedObject var store: IslandStore
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 13, weight: .semibold))

                VStack(alignment: .leading, spacing: 0) {
                    Text("Files")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    Text("\(store.files.count) of 5")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(islandTextColor.opacity(0.42))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .frame(height: 30)
            .padding(.top, 12)
            .padding(.leading, -8)
            .padding(.trailing, 12)

            if store.files.isEmpty {
                DropFilePlaceholder(isLarge: store.expandedSizeOption == .large)
                    .padding(.leading, -8)
                    .padding(.trailing, 12)
                    .padding(.bottom, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: store.expandedSizeOption == .large ? 12 : 10) {
                        ForEach(store.files) { file in
                            FilePreviewTile(
                                file: file,
                                isLarge: store.expandedSizeOption == .large,
                                reveal: { store.revealFile(file) },
                                remove: { store.removeFile(file) }
                            )
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 12)
                    .padding(.bottom, 10)
                }
            }
        }
    }
}

private struct DropFilePlaceholder: View {
    let isLarge: Bool
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        ZStack(alignment: .leading) {
            RadialGradient(
                colors: [
                    islandTextColor.opacity(0.065),
                    islandTextColor.opacity(0.020),
                    .clear
                ],
                center: .leading,
                startRadius: 8,
                endRadius: isLarge ? 260 : 210
            )

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(islandTextColor.opacity(0.075))
                        .frame(width: isLarge ? 48 : 42, height: isLarge ? 48 : 42)

                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: isLarge ? 24 : 21, weight: .semibold))
                        .foregroundStyle(islandTextColor.opacity(0.82))
                }
                .frame(width: isLarge ? 68 : 56, height: isLarge ? 96 : 78)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Drop anywhere")
                        .font(.system(size: isLarge ? 16 : 15, weight: .heavy, design: .rounded))
                        .lineLimit(1)

                    Text("Files blend into this shelf")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(islandTextColor.opacity(0.40))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: isLarge ? 20 : 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: isLarge ? 20 : 18, style: .continuous))
    }
}

private struct FilePreviewTile: View {
    let file: ShelfFile
    let isLarge: Bool
    let reveal: () -> Void
    let remove: () -> Void
    @State private var isHovered = false
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        TimelineView(.periodic(from: .now, by: 8.0)) { _ in
            let existsOnDisk = file.existsOnDisk

            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    FilePreviewVisual(
                        file: file,
                        size: previewSize,
                        existsOnDisk: existsOnDisk
                    )

                    HStack(spacing: 2) {
                        IconButton(systemName: "magnifyingglass", title: "Reveal in Finder", action: reveal)
                            .disabled(!existsOnDisk)
                        IconButton(systemName: "xmark", title: "Remove", action: remove)
                    }
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.58))
                    )
                    .padding(4)
                    .opacity(isHovered ? 1 : 0)
                    .scaleEffect(isHovered ? 1 : 0.92, anchor: .topTrailing)
                }

                Text(file.displayName)
                    .font(.system(size: isLarge ? 10 : 9.5, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .truncationMode(.middle)
                    .frame(width: tileWidth, height: isLarge ? 28 : 26, alignment: .top)
                    .foregroundStyle(islandTextColor.opacity(existsOnDisk ? 0.82 : 0.42))
            }
            .frame(width: tileWidth)
            .modifier(FileDragOutModifier(file: file, isEnabled: existsOnDisk))
            .opacity(existsOnDisk ? 1 : 0.58)
            .help(existsOnDisk ? "Drag out as a file" : "Missing")
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.14)) {
                    isHovered = hovering
                }
            }
        }
    }

    private var tileWidth: CGFloat {
        isLarge ? 92 : 80
    }

    private var previewSize: CGSize {
        isLarge ? CGSize(width: 82, height: 96) : CGSize(width: 66, height: 74)
    }
}

private struct FilePreviewVisual: View {
    let file: ShelfFile
    let size: CGSize
    let existsOnDisk: Bool
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(islandTextColor.opacity(0.040))

            if existsOnDisk, let image = FileVisualCache.preview(for: file.url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                Image(nsImage: FileVisualCache.icon(for: file.url, size: iconSize))
                    .resizable()
                    .scaledToFit()
                    .padding(9)
                    .opacity(existsOnDisk ? 1 : 0.55)
            }

            if !existsOnDisk {
                Text("Missing")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.orange.opacity(0.95))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.72))
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(islandTextColor.opacity(0.08), lineWidth: 1)
        )
    }

    private var iconSize: CGSize {
        CGSize(width: size.width * 0.66, height: size.height * 0.66)
    }
}

@MainActor
private enum FileVisualCache {
    private static var imagePreviews: [String: NSImage] = [:]
    private static var icons: [String: NSImage] = [:]

    static func preview(for url: URL) -> NSImage? {
        let key = url.path
        if let image = imagePreviews[key] {
            return image
        }

        guard let type = UTType(filenameExtension: url.pathExtension),
              type.conforms(to: .image),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        imagePreviews[key] = image
        return image
    }

    static func icon(for url: URL, size: CGSize) -> NSImage {
        let key = "\(url.path)#\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
        if let icon = icons[key] {
            return icon
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = size
        icons[key] = icon
        return icon
    }
}

private extension ClipboardEntry {
    var dockTitle: String {
        value
    }

    var kindLabel: String {
        switch kind {
        case .image:
            return "Image"
        case .link:
            return "Link"
        case .text:
            return "Text"
        }
    }
}

private struct ShelfSection: View {
    @ObservedObject var store: IslandStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "File Shelf", detail: "\(store.files.count)/5")

            if store.files.isEmpty {
                EmptyRow(systemName: "arrow.down.doc", text: "Drag files onto the island")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(store.files) { file in
                            FileRow(
                                file: file,
                                reveal: { store.revealFile(file) },
                                remove: { store.removeFile(file) }
                            )
                        }
                    }
                }
                .frame(maxHeight: store.expandedSizeOption == .large ? 88 : 44)
            }
        }
    }
}

private struct ClipboardSection: View {
    @ObservedObject var store: IslandStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Clipboard", detail: "\(store.clipboardEntries.count)/5")

            if store.clipboardEntries.isEmpty {
                EmptyRow(
                    systemName: store.isClipboardPaused ? "pause.circle" : "doc.on.clipboard",
                    text: store.isClipboardPaused ? "Clipboard watching is paused" : "Copy text, links, or images"
                )
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(store.clipboardEntries) { entry in
                            ClipboardRow(
                                entry: entry,
                                copy: { store.copyClipboardEntry(entry) },
                                inspect: { store.inspectClipboardEntry(entry) }
                            )
                        }
                    }
                }
                .frame(maxHeight: store.expandedSizeOption == .large ? 88 : 44)
            }
        }
        .popover(item: detailPopoverBinding, arrowEdge: .bottom) { entry in
            ClipboardDetailPopover(
                entry: entry,
                copy: { store.copyClipboardEntry(entry) },
                close: { store.closeClipboardDetail() },
                hoverChanged: { store.setClipboardDetailHovered($0) }
            )
        }
        .transaction { transaction in
            transaction.disablesAnimations = store.inspectedClipboardEntry == nil
        }
    }

    private var detailPopoverBinding: Binding<ClipboardEntry?> {
        Binding(
            get: { store.inspectedClipboardEntry },
            set: { entry in
                var transaction = Transaction()
                transaction.disablesAnimations = entry == nil

                withTransaction(transaction) {
                    store.setClipboardDetailFromPopover(entry)
                }
            }
        )
    }
}

private struct FileRow: View {
    let file: ShelfFile
    let reveal: () -> Void
    let remove: () -> Void
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        TimelineView(.periodic(from: .now, by: 8.0)) { _ in
            let existsOnDisk = file.existsOnDisk

            fileRowContent(existsOnDisk: existsOnDisk)
                .modifier(FileDragOutModifier(file: file, isEnabled: existsOnDisk))
                .opacity(existsOnDisk ? 1 : 0.58)
                .help(existsOnDisk ? "Drag out as a file" : "Missing")
        }
    }

    private func fileRowContent(existsOnDisk: Bool) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: FileIconCache.icon(for: file.url))
                .resizable()
                .frame(width: 18, height: 18)
                .modifier(FileDragOutModifier(file: file, isEnabled: existsOnDisk))

            Text(file.displayName)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            if !existsOnDisk {
                Text("Missing")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.orange.opacity(0.95))
                    .lineLimit(1)
            }

            IconButton(systemName: "magnifyingglass", title: "Reveal in Finder", action: reveal)
                .disabled(!existsOnDisk)
            IconButton(systemName: "xmark", title: "Remove", action: remove)
        }
        .padding(.horizontal, 10)
        .frame(height: 27)
        .background(rowBackground)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(islandTextColor.opacity(0.08))
    }
}

@MainActor
private enum FileIconCache {
    private static var icons: [String: NSImage] = [:]

    static func icon(for url: URL) -> NSImage {
        let key = url.path
        if let icon = icons[key] {
            return icon
        }

        let icon = NSWorkspace.shared.icon(forFile: key)
        icon.size = CGSize(width: 18, height: 18)
        icons[key] = icon
        return icon
    }
}

private struct FileDragOutModifier: ViewModifier {
    let file: ShelfFile
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .onDrag {
                    file.makeDragItemProvider()
                }
        } else {
            content
        }
    }
}

private struct ClipboardRow: View {
    let entry: ClipboardEntry
    let copy: () -> Void
    let inspect: () -> Void
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 8) {
            Button(action: primaryAction) {
                HStack(spacing: 8) {
                    leadingVisual

                    Text(entry.value)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(IslandButtonPressStyle())
            .help(entry.kind == .image ? "Preview image" : "Show full copied text")

            IconButton(systemName: "doc.on.doc", title: "Copy back to clipboard", action: copy)
        }
        .padding(.horizontal, 10)
        .frame(height: 27)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(islandTextColor.opacity(0.08))
        )
    }

    private func primaryAction() {
        inspect()
    }

    @ViewBuilder
    private var leadingVisual: some View {
        switch entry.kind {
        case .image:
            if let image = entry.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 24, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(islandTextColor.opacity(0.18), lineWidth: 1)
                    )
            } else {
                fallbackIcon(systemName: "photo")
            }
        case .link:
            fallbackIcon(systemName: "link")
        case .text:
            fallbackIcon(systemName: "text.alignleft")
        }
    }

    private func fallbackIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 16)
    }
}

private struct ClipboardDetailPopover: View {
    let entry: ClipboardEntry
    let copy: () -> Void
    let close: () -> Void
    let hoverChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: headerIconName)
                    .font(.system(size: 12, weight: .semibold))

                Text(headerTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))

                Spacer(minLength: 8)

                IconButton(systemName: "doc.on.doc", title: "Copy back to clipboard", action: copy)
                IconButton(systemName: "xmark", title: "Close preview", action: close)
            }

            detailContent
        }
        .padding(12)
        .frame(width: 390)
        .foregroundStyle(.white)
        .background(Color.black.opacity(0.92))
        .onHover(perform: hoverChanged)
        .onDisappear {
            hoverChanged(false)
        }
    }

    private var headerIconName: String {
        switch entry.kind {
        case .image:
            return "photo"
        case .link:
            return "link"
        case .text:
            return "text.alignleft"
        }
    }

    private var headerTitle: String {
        switch entry.kind {
        case .image:
            return entry.value
        case .link:
            return "Copied Link"
        case .text:
            return "Copied Text"
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if entry.kind == .image, let image = entry.image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 360, height: 220)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                Text(entry.value)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(10)
            }
            .frame(width: 360, height: 190)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let detail: String
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Text(detail)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(islandTextColor.opacity(0.56))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(islandTextColor.opacity(0.10))
                )
        }
        .padding(.leading, 4)
    }
}

private struct EmptyRow: View {
    let systemName: String
    let text: String
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(islandTextColor.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.80)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(islandTextColor.opacity(0.06))
        )
    }
}

private struct StatusDot: View {
    let isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.22))
                .frame(width: 28, height: 28)

            Circle()
                .fill(isActive ? Color.cyan : Color.green)
                .frame(width: 10, height: 10)
                .shadow(color: (isActive ? Color.cyan : Color.green).opacity(0.5), radius: 8)
        }
    }
}

private struct MiniStatusDot: View {
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 8, height: 8)
            .shadow(color: Color.green.opacity(0.55), radius: 5)
    }
}

private struct MiniIslandSignal: View {
    let systemName: String
    let count: Int
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(islandTextColor.opacity(0.86))
        .frame(minWidth: 35, minHeight: 20)
        .background(
            Capsule()
                .fill(Color.clear)
        )
    }
}

private struct CountBadge: View {
    let systemName: String
    let count: Int
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(islandTextColor.opacity(0.10))
        )
    }
}

private struct IslandButtonPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct IconButton: View {
    let systemName: String
    let title: String
    let action: () -> Void
    @State private var isConfirming = false
    @State private var isHovered = false
    @State private var confirmationTask: Task<Void, Never>?
    @Environment(\.islandTextColor) private var islandTextColor
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: handleTap) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .opacity(iconOpacity)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(islandTextColor.opacity(backgroundOpacity))
                        .scaleEffect(isConfirming ? 1.05 : (isHovered ? 1.0 : 0.72))
                )
                .scaleEffect(isConfirming ? 0.88 : 1.0)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.13)) {
                isHovered = hovering && isEnabled
            }
        }
        .onDisappear {
            confirmationTask?.cancel()
        }
    }

    private var iconOpacity: CGFloat {
        guard isEnabled else { return 0.34 }
        return isHovered ? 1.0 : 0.88
    }

    private var backgroundOpacity: CGFloat {
        if isConfirming { return 0.22 }
        return isHovered ? 0.12 : 0.0
    }

    private func handleTap() {
        action()
        confirmationTask?.cancel()

        withAnimation(.easeOut(duration: 0.04)) {
            isConfirming = true
        }

        confirmationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 55_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.07)) {
                isConfirming = false
            }
            confirmationTask = nil
        }
    }
}

private struct GreenSwitchToggleStyle: ToggleStyle {
    @Environment(\.islandTextColor) private var islandTextColor

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.11, dampingFraction: 0.82, blendDuration: 0.01)) {
                configuration.isOn.toggle()
            }
        } label: {
            Capsule()
                .fill(configuration.isOn ? Color(red: 0.18, green: 0.70, blue: 0.34) : islandTextColor.opacity(0.18))
                .frame(width: 34, height: 20)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white.opacity(0.96))
                        .frame(width: 16, height: 16)
                        .shadow(color: Color.black.opacity(0.22), radius: 1.5, x: 0, y: 1)
                        .padding(2)
                }
                .overlay {
                    Capsule()
                        .stroke(islandTextColor.opacity(configuration.isOn ? 0.18 : 0.12), lineWidth: 1)
                }
        }
        .buttonStyle(IslandButtonPressStyle())
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = IslandStore()
    private var islandController: IslandWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenuBarItem()

        let controller = IslandWindowController(store: store)
        islandController = controller
        controller.show()

        store.startClipboardWatcher()
        store.startNowPlayingWatcher()
        store.startAirPodsWatcher()
        store.startSystemControlWatcher()
        store.startPowerWatcher()
        store.startWeatherWatcher()
        store.startNBAScoresWatcher()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.shutdown()
    }

    private func configureMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "capsule",
                accessibilityDescription: "MacBook Dynamic Island"
            )
            button.toolTip = "MacBook Dynamic Island"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@main
private enum MacBookDynamicIslandApp {
    @MainActor
    private static var appDelegate: AppDelegate?

    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()

        appDelegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
