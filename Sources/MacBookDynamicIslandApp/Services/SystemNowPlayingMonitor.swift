import Foundation
import MacBookDynamicIslandCore
import os

private let nowPlayingLog = Logger(subsystem: "local.hannan.MacBookDynamicIslandApp", category: "now-playing")

/// Runs the Now Playing helper script and reports what it prints.
///
/// The helper is a child `osascript` process (see `SystemNowPlayingHelperScript`
/// for why). If it dies it is restarted with a growing delay; after repeated
/// failures the monitor gives up and stays `unavailable`, which lets the store
/// fall back to asking Apple Music directly.
@MainActor
final class SystemNowPlayingMonitor {
    enum Event {
        case snapshot(SystemNowPlayingSnapshot)
        /// The helper is not delivering data (failed to start, exited, or went silent at launch).
        case unavailable
    }

    var onEvent: ((Event) -> Void)?

    private var process: Process?
    private var parser = SystemNowPlayingStreamParser()
    private var restartTask: Task<Void, Never>?
    private var startupTimeoutTask: Task<Void, Never>?
    private var isRunning = false
    private var hasReceivedSnapshot = false
    private var consecutiveFailures = 0
    /// Bumped on every launch so callbacks from an older helper process are ignored.
    private var generation = 0

    private static let maximumConsecutiveFailures = 5
    private static let startupTimeout: UInt64 = 4_000_000_000

    func start() {
        guard !isRunning else { return }
        isRunning = true
        consecutiveFailures = 0
        launch()
    }

    func stop() {
        isRunning = false
        generation += 1
        restartTask?.cancel()
        restartTask = nil
        startupTimeoutTask?.cancel()
        startupTimeoutTask = nil
        terminateProcess()
    }

    private func launch() {
        generation += 1
        let generation = generation
        parser = SystemNowPlayingStreamParser()
        hasReceivedSnapshot = false

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-e", SystemNowPlayingHelperScript.source]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        // Both callbacks arrive on background queues; hop to the main queue (FIFO,
        // so chunks stay in order) before touching any state.
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else {
                handle.readabilityHandler = nil
                return
            }

            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.consume(chunk, generation: generation)
                }
            }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.handleTermination(generation: generation)
                }
            }
        }

        do {
            try process.run()
        } catch {
            nowPlayingLog.error("Could not launch Now Playing helper: \(String(describing: error), privacy: .public)")
            output.fileHandleForReading.readabilityHandler = nil
            handleTermination(generation: generation)
            return
        }

        self.process = process
        startupTimeoutTask?.cancel()
        startupTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.startupTimeout)
            guard !Task.isCancelled, let self,
                  self.generation == generation,
                  !self.hasReceivedSnapshot else { return }

            nowPlayingLog.notice("Now Playing helper produced no data at launch")
            self.onEvent?(.unavailable)
        }
    }

    private func consume(_ chunk: Data, generation: Int) {
        guard isRunning, generation == self.generation else { return }

        for snapshot in parser.append(chunk) {
            if let error = snapshot.error {
                nowPlayingLog.error("Now Playing helper reported: \(error, privacy: .public)")
                onEvent?(.unavailable)
                continue
            }

            hasReceivedSnapshot = true
            consecutiveFailures = 0
            onEvent?(.snapshot(snapshot))
        }
    }

    private func handleTermination(generation: Int) {
        guard isRunning, generation == self.generation else { return }

        process = nil
        startupTimeoutTask?.cancel()
        startupTimeoutTask = nil
        consecutiveFailures += 1
        onEvent?(.unavailable)

        guard consecutiveFailures < Self.maximumConsecutiveFailures else {
            nowPlayingLog.error("Now Playing helper keeps exiting; giving up")
            return
        }

        let delay = UInt64(min(60, pow(2.0, Double(consecutiveFailures)))) * 1_000_000_000
        nowPlayingLog.notice("Now Playing helper exited; restarting (attempt \(self.consecutiveFailures, privacy: .public))")

        restartTask?.cancel()
        restartTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, let self, self.isRunning, self.generation == generation else { return }
            self.launch()
        }
    }

    private func terminateProcess() {
        guard let process else { return }

        (process.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        process.terminationHandler = nil
        if process.isRunning {
            process.terminate()
        }
        self.process = nil
    }
}
