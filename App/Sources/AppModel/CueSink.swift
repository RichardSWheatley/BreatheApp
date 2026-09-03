import BreatheKit
import Foundation

/// Where cues go. The real implementation plays audio, speech and haptics;
/// UI tests and unit tests substitute silent or recording sinks.
@MainActor
protocol CueSink: AnyObject {
    /// Called once before the first cue of a session (activate audio, warm up haptics).
    func sessionWillStart()
    /// Called once after the session finishes or is abandoned.
    func sessionDidEnd()
    func play(_ cue: Cue)
}

@MainActor
final class SilentCueSink: CueSink {
    func sessionWillStart() {}
    func sessionDidEnd() {}
    func play(_ cue: Cue) {}
}
