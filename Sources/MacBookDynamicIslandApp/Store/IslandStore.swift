import AppKit
import IOKit
import MacBookDynamicIslandCore
import SwiftUI

@MainActor
final class IslandStore: ObservableObject {
    @Published var islandMode: IslandMode = .player {
        didSet {
            noteModeChange(from: oldValue)
        }
    }
    /// Which way the latest mode change travelled along the switcher: +1 towards
    /// the next mode, -1 towards the previous one. New content slides in from that side.
    private(set) var modeChangeDirection: CGFloat = 1
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

    // MARK: - Feature state
    // Internal rather than private so the per-feature extensions in
    // IslandStore+*.swift can share it. Views should only use the @Published API.

    // Now playing
    let systemNowPlayingMonitor = SystemNowPlayingMonitor()
    var nowPlayingSource: NowPlayingSource = .starting
    var latestSystemSnapshot: SystemNowPlayingSnapshot?
    var systemTrackKey: String?
    var systemArtwork: NSImage?
    var lastSystemNowPlayingApplyDate = Date.distantPast
    var nowPlayingReconcileTask: Task<Void, Never>?
    var optimisticPlaybackState: MediaPlaybackState?
    var optimisticPlaybackDeadline = Date.distantPast
    var nowPlayingTimer: Timer?
    var deferredNowPlayingRefreshTask: Task<Void, Never>?
    var lastNowPlayingRefreshDate = Date.distantPast
    var artworkLookupTask: Task<Void, Never>?
    var pendingArtworkLookupKey: String?
    var artworkCache: [String: Data] = [:]
    var artworkCacheKeys: [String] = []
    var artworkLookupMisses: [String: Date] = [:]
    static let artworkLookupMissRetryInterval: TimeInterval = 10 * 60

    // Weather
    var weatherTimer: Timer?
    var weatherRefreshTask: Task<Void, Never>?
    var weatherLocation: WeatherLocation?
    var lastWeatherRefreshDate = Date.distantPast
    static let weatherRefreshInterval: TimeInterval = 30 * 60

    // NBA scores
    var nbaScoresTimer: Timer?
    var nbaScoreboardTask: Task<Void, Never>?
    var nbaBoxScoreTask: Task<Void, Never>?
    var lastNBAScoreboardRefreshDate = Date.distantPast
    var lastNBABoxScoreRefreshDates: [String: Date] = [:]
    var nbaScoreboardFailureCount = 0
    var nbaBoxScoreFailureCounts: [String: Int] = [:]
    var nbaBoxScoreCache: [String: NBABoxScore] = [:]
    var nbaBoxScoreCacheKeys: [String] = []

    // Clipboard and file shelf
    var clipboardTimer: Timer?
    var lastPasteboardChangeCount: Int
    var suppressNextClipboardDetailDismissal = false
    var shouldConsumeNextOutsideCollapse = false
    var clipboardDetailDismissalGuardUntil = Date.distantPast
    let concealedPasteboardTypes: Set<NSPasteboard.PasteboardType> = [
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")
    ]

    // Volume, brightness, AirPods, and charging feedback
    var audioOutputTimer: Timer?
    var systemControlTimer: Timer?
    var powerSourceRunLoopSource: CFRunLoopSource?
    var displayBrightnessNotificationPort: IONotificationPortRef?
    var displayBrightnessInterest: io_object_t = 0
    var lastOutputDeviceName: String?
    var lastOutputWasAirPods = false
    var lastOutputVolume: Float?
    var lastDisplayBrightness: Float?
    var lastPowerWasConnected = false
    var airPodsBannerTask: Task<Void, Never>?
    var chargingBannerTask: Task<Void, Never>?
    var systemControlFeedbackTask: Task<Void, Never>?
    var displayBrightnessRefreshTask: Task<Void, Never>?
    static let systemControlChangeThreshold: Float = 0.01
    static let ioMessageServicePropertyChange = UInt32(0xE0000130)

    private var ambientRefreshPausedUntil = Date.distantPast

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

    // MARK: - Appearance and layout

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

    var modeSelectorWidth: CGFloat {
        CGFloat(visibleModes.count) * 20 + 2
    }

    /// How far left of the island's centre line (the notch) the centre of the mode
    /// switcher sits. It is measured from the narrowest mode, so the switcher sits
    /// in that mode's top-left corner and then stays at the same spot on screen
    /// when a wider mode opens around it: the icons never move under the pointer.
    var modeSelectorCenterOffset: CGFloat {
        let narrowestWidth = visibleModes.map { expandedSize(for: $0).width }.min()
            ?? expandedSize(for: islandMode).width
        return narrowestWidth / 2 - IslandMetrics.modeSelectorOrigin.x - modeSelectorWidth / 2
    }

    /// The switcher's right edge, measured from the left edge of `mode`'s island.
    /// Content that shares the top band with the switcher starts after this.
    func modeSelectorTrailingEdge(in mode: IslandMode) -> CGFloat {
        expandedSize(for: mode).width / 2 - modeSelectorCenterOffset + modeSelectorWidth / 2
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

    // MARK: - Lifecycle

    func shutdown() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
        audioOutputTimer?.invalidate()
        audioOutputTimer = nil
        systemControlTimer?.invalidate()
        systemControlTimer = nil
        nowPlayingTimer?.invalidate()
        nowPlayingTimer = nil
        systemNowPlayingMonitor.stop()
        nowPlayingReconcileTask?.cancel()
        nowPlayingReconcileTask = nil
        latestSystemSnapshot = nil
        systemTrackKey = nil
        systemArtwork = nil
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

    // MARK: - Modes

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

        // A swipe keeps travelling the way the fingers went, even when it wraps
        // around from the last mode to the first.
        modeChangeDirection = offset < 0 ? -1 : 1
    }

    private func noteModeChange(from previousMode: IslandMode) {
        let modes = visibleModes
        guard previousMode != islandMode,
              let previousIndex = modes.firstIndex(of: previousMode),
              let index = modes.firstIndex(of: islandMode) else {
            return
        }

        modeChangeDirection = index < previousIndex ? -1 : 1
    }

    func pauseAmbientRefreshes(for duration: TimeInterval) {
        ambientRefreshPausedUntil = max(ambientRefreshPausedUntil, Date().addingTimeInterval(duration))
    }

    // MARK: - Setting change handlers

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

    static func uniquedHomeWidgets(_ widgets: [HomeWidget]) -> [HomeWidget] {
        var seen = Set<HomeWidget>()
        return widgets.filter { widget in
            guard !seen.contains(widget) else { return false }
            seen.insert(widget)
            return true
        }
    }

    var ambientRefreshesArePaused: Bool {
        Date() < ambientRefreshPausedUntil
    }
}
