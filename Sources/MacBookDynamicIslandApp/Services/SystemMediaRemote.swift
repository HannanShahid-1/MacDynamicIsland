import Darwin
import Foundation
import MacBookDynamicIslandCore

/// Sends play/pause/skip to whichever app currently owns the system's Now
/// Playing slot. Unlike reading Now Playing info, sending commands is still
/// allowed from an ordinary app, so no helper process is needed.
@MainActor
enum SystemMediaRemote {
    private typealias SendCommandFunction = @convention(c) (UInt32, CFDictionary?) -> Bool

    private static let sendCommand: SendCommandFunction? = {
        let frameworkPath = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"

        guard let handle = dlopen(frameworkPath, RTLD_LAZY),
              let symbol = dlsym(handle, "MRMediaRemoteSendCommand") else {
            return nil
        }

        return unsafeBitCast(symbol, to: SendCommandFunction.self)
    }()

    @discardableResult
    static func send(_ command: SystemMediaCommand) -> Bool {
        guard let sendCommand else { return false }
        return sendCommand(UInt32(command.rawValue), nil)
    }
}
