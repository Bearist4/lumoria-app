import UIKit

/// Coarse device-tier gate used to degrade expensive shimmer modes on
/// older silicon. Current rule: A12 and below → no holographic.
enum DeviceTier {
    case high   // A13 and newer
    case low

    static var current: DeviceTier {
        var info = utsname()
        uname(&info)
        let model = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        // A12 devices: iPhone XS/XS Max/XR use "iPhone11,x"; iPad Pro
        // 2018 uses "iPad8,x"; iPad Air 3 is "iPad11,3/4". iPhone 11
        // series (A13) is "iPhone12,x".
        let lowerModels = ["iPhone11,", "iPad8,", "iPad11,3", "iPad11,4"]
        if lowerModels.contains(where: { model.hasPrefix($0) }) {
            return .low
        }
        return .high
    }
}
