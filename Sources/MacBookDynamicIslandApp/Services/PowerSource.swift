import AppKit
import IOKit
import IOKit.ps

@MainActor
enum PowerSource {
    static func isConnectedToPower() -> Bool {
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

    static func currentBatteryPercentage() -> Int? {
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
}
