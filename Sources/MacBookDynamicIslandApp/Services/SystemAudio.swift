import CoreAudio
import Foundation

@MainActor
enum SystemAudio {
    static func currentOutputDeviceName() -> String? {
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

    static func currentOutputVolume() -> Float? {
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
