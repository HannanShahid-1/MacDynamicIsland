import AppKit
import Combine
import IOKit.hidsystem
import SwiftUI

@MainActor
final class IslandWindowController {
    private let store: IslandStore
    private let panel: IslandPanel
    private var cancellables = Set<AnyCancellable>()
    private var globalMouseDownMonitor: Any?
    private var globalSystemControlMonitor: Any?
    private var localMouseDownMonitor: Any?
    private var localSwipeMonitor: Any?
    private var modeSwipeAccumulatedX: CGFloat = 0
    private var lastModeSwipeTime = Date.distantPast
    private var frameTrimTask: Task<Void, Never>?
    private var lastSyncedTarget: CGRect?

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
        syncFrame(settling: false)
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
            .sink { [weak self] _, _, _, _ in
                guard let self else { return }

                self.syncFrame()
                self.syncOutsideClickMonitoring()
            }
            .store(in: &cancellables)

        // Everything else that changes the island's resting size.
        Publishers.MergeMany(
            store.$systemControlFeedback.map { _ in () }.eraseToAnyPublisher(),
            store.$islandMode.map { _ in () }.eraseToAnyPublisher(),
            store.$layoutMode.map { _ in () }.eraseToAnyPublisher(),
            store.$homeWidgets.map { _ in () }.eraseToAnyPublisher(),
            store.$expandedSizeOption.map { _ in () }.eraseToAnyPublisher(),
            store.$selectedNBAGameID.removeDuplicates().map { _ in () }.eraseToAnyPublisher()
        )
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.syncFrame()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncFrame(settling: false)
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

        if windowNumber == panel.windowNumber, islandContains(locationInWindow) {
            return
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
              islandContains(locationInWindow),
              momentumPhase == [] else {
            return
        }

        // A sideways swipe over a row that scrolls sideways (the NBA game strip,
        // the file shelf) belongs to that row, not to the mode switcher.
        if let contentView = panel.contentView,
           ScrollHitTesting.isOverHorizontallyScrollableContent(locationInWindow, in: contentView) {
            modeSwipeAccumulatedX = 0
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

        store.pauseAmbientRefreshes(for: IslandMotion.quietTime)
        withAnimation(IslandMotion.select) {
            if modeSwipeAccumulatedX < 0 {
                store.showNextMode()
            } else {
                store.showPreviousMode()
            }
        }

        modeSwipeAccumulatedX = 0
    }

    /// Whether a point in window coordinates is on the island itself, as opposed
    /// to the transparent room the window keeps around it.
    private func islandContains(_ locationInWindow: CGPoint) -> Bool {
        guard let contentView = panel.contentView else { return false }

        let size = currentSize
        let bounds = contentView.bounds
        let islandRect = CGRect(
            x: bounds.midX - size.width / 2,
            y: contentView.isFlipped ? bounds.minY : bounds.maxY - size.height,
            width: size.width,
            height: size.height
        )
        return islandRect.contains(contentView.convert(locationInWindow, from: nil))
    }

    // MARK: - Window frame
    //
    // SwiftUI does all the animating: the island's surface springs between sizes
    // inside a window that never animates. The window only has to be big enough
    // at every moment, so it grows at once to cover both where the surface is and
    // where it is going, then trims back once the spring has settled. It also
    // keeps `IslandMetrics.motionOverscan` of transparent room so the surface can
    // overshoot its resting size.

    private func prepareForExpansion() {
        growFrame(toInclude: frame(fitting: expandedSizeForCurrentMode))
        scheduleFrameTrim()
    }

    /// Makes the window fit the island's current resting size. While `settling`,
    /// shrinking waits for the surface's spring to finish.
    private func syncFrame(settling: Bool = true) {
        let target = frame(fitting: currentSize)

        guard settling, panel.isVisible else {
            frameTrimTask?.cancel()
            frameTrimTask = nil
            lastSyncedTarget = target
            setFrameIfNeeded(target)
            return
        }

        // The store republishes values that have not changed. Those must not keep
        // pushing the trim back, or the window would never shrink again.
        if let lastSyncedTarget, Self.framesMatch(lastSyncedTarget, target) {
            return
        }
        lastSyncedTarget = target

        growFrame(toInclude: target)
        scheduleFrameTrim()
    }

    private func growFrame(toInclude target: CGRect) {
        setFrameIfNeeded(panel.frame.union(target))
    }

    private func scheduleFrameTrim() {
        frameTrimTask?.cancel()
        frameTrimTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(IslandMotion.settleTime * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }

            self.setFrameIfNeeded(self.frame(fitting: self.currentSize))
            self.frameTrimTask = nil
        }
    }

    private func setFrameIfNeeded(_ frame: CGRect) {
        guard !Self.framesMatch(panel.frame, frame) else { return }

        // Resize and lay out in one pass so the island, which is pinned to the
        // top centre of the window, does not appear to move.
        panel.setFrame(frame, display: true)
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
    }

    private func frame(fitting islandSize: CGSize) -> CGRect {
        let overscan = IslandMetrics.motionOverscan
        let windowSize = CGSize(
            width: islandSize.width + overscan.width * 2,
            height: islandSize.height + overscan.height
        )
        return ScreenPositioner.frame(for: windowSize, on: panel.screen)
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
