import Foundation

/// Locale-independent time formatting shared by the app and the simulator.
public enum TimeFormatting {
    /// "1:45" style clock string. Values below one minute still show "0:07".
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let minutes = total / 60
        let secs = total % 60
        return "\(minutes):" + (secs < 10 ? "0\(secs)" : "\(secs)")
    }

    /// "45 s", "2 min", "2 min 15 s".
    public static func spoken(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let secs = total % 60
        switch (minutes, secs) {
        case (0, _): return "\(secs) s"
        case (_, 0): return "\(minutes) min"
        default: return "\(minutes) min \(secs) s"
        }
    }

    /// Whole seconds, e.g. "45s".
    public static func compact(_ seconds: TimeInterval) -> String {
        "\(Int(seconds.rounded()))s"
    }
}
