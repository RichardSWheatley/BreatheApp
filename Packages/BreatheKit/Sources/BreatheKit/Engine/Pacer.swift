import Foundation

/// Pure functions that turn engine state into the "expanding / contracting
/// circle" the PRD asks for. Kept out of the view layer so they can be tested.
public enum Pacer {
    /// Lung fullness on a 0 (empty) ... 1 (full) scale.
    ///
    /// - Parameters:
    ///   - phase: the current step's phase.
    ///   - progress: 0...1 progress through a timed step, `nil` when open-ended.
    ///   - elapsed: seconds into the step, used by phases without a fixed target.
    public static func fullness(phase: BreathPhase, progress: Double?, elapsed: TimeInterval) -> Double {
        let p = min(max(progress ?? 0, 0), 1)
        switch phase {
        case .inhale, .resistedInhale:
            return eased(p)
        case .exhale:
            return 1 - eased(p)
        case .holdFull:
            return 1
        case .holdEmpty, .walkHold:
            return 0
        case .countAloud:
            // Lungs empty gradually over the count; one minute is a very long count.
            return max(0, 1 - elapsed / 60)
        case .prepare, .recover, .rest, .complete:
            return freeBreathing(elapsed: elapsed)
        }
    }

    /// A gentle oscillation between 0.25 and 0.75 for free-breathing phases.
    /// Starts near "empty" so the transition into the next inhale is natural.
    public static func freeBreathing(elapsed: TimeInterval, period: TimeInterval = 8) -> Double {
        guard period > 0 else { return 0.5 }
        let position = elapsed.truncatingRemainder(dividingBy: period) / period
        return 0.5 - 0.25 * cos(2 * .pi * position)
    }

    /// Smoothstep easing: slow start, brisk middle, soft landing.
    public static func eased(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }

    /// Maps fullness to a circle scale that never collapses to nothing.
    public static func scale(fullness: Double, minimum: Double = 0.45, maximum: Double = 1.0) -> Double {
        let f = min(max(fullness, 0), 1)
        return minimum + (maximum - minimum) * f
    }
}
