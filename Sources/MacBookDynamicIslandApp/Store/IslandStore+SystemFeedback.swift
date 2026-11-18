import Foundation
import IOKit
import IOKit.ps

extension IslandStore {
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

        lastPowerWasConnected = PowerSource.isConnectedToPower()

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

        guard let service = DisplayBrightness.currentAppleARMBacklightService() else { return }
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

    func stopDisplayBrightnessWatcher() {
        if displayBrightnessInterest != 0 {
            IOObjectRelease(displayBrightnessInterest)
            displayBrightnessInterest = 0
        }

        if let displayBrightnessNotificationPort {
            IONotificationPortDestroy(displayBrightnessNotificationPort)
            self.displayBrightnessNotificationPort = nil
        }
    }

    private func refreshCurrentAudioOutput(triggerBanner: Bool) {
        guard let name = SystemAudio.currentOutputDeviceName() else {
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
        let currentVolume = SystemAudio.currentOutputVolume()
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

        let currentBrightness = DisplayBrightness.current()
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
        guard let currentBrightness = DisplayBrightness.current() else {
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
        let immediateLevel = DisplayBrightness.current() ?? lastDisplayBrightness ?? 0.5
        lastDisplayBrightness = immediateLevel
        showSystemControlFeedback(kind: .brightness, level: immediateLevel)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 90_000_000)
            guard let updatedLevel = DisplayBrightness.current() else { return }

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
        let isConnected = PowerSource.isConnectedToPower()
        let didConnect = isConnected && !lastPowerWasConnected
        lastPowerWasConnected = isConnected

        if didConnect {
            showChargingBanner()
        }
    }

    private func showChargingBanner() {
        guard !isExpanded, !isDragTargeted else { return }

        chargingBannerTask?.cancel()
        chargingBatteryPercent = PowerSource.currentBatteryPercentage()
        chargingBannerID = UUID()

        chargingBannerTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_100_000_000)
            guard !Task.isCancelled else { return }
            chargingBannerID = nil
            chargingBatteryPercent = nil
            chargingBannerTask = nil
        }
    }

    private static func isAirPodsDeviceName(_ name: String) -> Bool {
        name.localizedCaseInsensitiveContains("AirPods")
    }
}
