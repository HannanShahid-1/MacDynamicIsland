import AppKit
import CoreGraphics
import Darwin
import IOKit
import IOKit.graphics

@MainActor
enum DisplayBrightness {
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

    static func current() -> Float? {
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

    static func currentAppleARMBacklightService() -> io_service_t? {
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
}
