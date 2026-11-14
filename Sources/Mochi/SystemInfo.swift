import AppKit
import IOKit.ps

/// Small, permission-free facts about the Mac and the person using it.
enum SystemInfo {
    /// Seconds since the last keyboard / mouse / trackpad input.
    static func userIdleSeconds() -> TimeInterval {
        guard let any = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: any)
    }

    /// Internal battery level and whether it's charging (nil on Macs without a battery).
    static func battery() -> (level: Int, charging: Bool)? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let level = d[kIOPSCurrentCapacityKey] as? Int else { continue }
            let onAC = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return (level, onAC)
        }
        return nil
    }
}
