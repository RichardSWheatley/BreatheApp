import Foundation

/// Parameters for Hypoxic Sprints (PRD §4B).
///
/// Each repetition is an exhale-and-hold while walking a computed number of
/// paces, followed by one minute of normal breathing.
public struct HypoxicSprintParameters: Codable, Sendable, Hashable {
    public var reps: Int
    public var recovery: TimeInterval
    /// Fraction of the (full-lung) max hold used for the empty-lung walking hold.
    public var walkFraction: Double
    public var minimumWalk: TimeInterval
    public var maximumWalk: TimeInterval
    /// Walking cadence used to convert seconds to paces (paces per second).
    public var pacesPerSecond: Double
    public var prepareDuration: TimeInterval

    public init(
        reps: Int = 6,
        recovery: TimeInterval = 60,
        walkFraction: Double = 0.3,
        minimumWalk: TimeInterval = 10,
        maximumWalk: TimeInterval = 45,
        pacesPerSecond: Double = 100.0 / 60.0,
        prepareDuration: TimeInterval = 15
    ) {
        self.reps = reps
        self.recovery = recovery
        self.walkFraction = walkFraction
        self.minimumWalk = minimumWalk
        self.maximumWalk = maximumWalk
        self.pacesPerSecond = pacesPerSecond
        self.prepareDuration = prepareDuration
    }

    public static let standard = HypoxicSprintParameters()
    /// The PRD prescribes 5–10 repetitions.
    public static let repRange = 5...10
}

public enum HypoxicSprints {
    /// Seconds of walking breath hold derived from the max hold.
    public static func walkDuration(maxHold: TimeInterval, parameters: HypoxicSprintParameters = .standard) -> TimeInterval {
        let maxHold = ApneaTables.clampedMaxHold(maxHold)
        let raw = (maxHold * parameters.walkFraction).rounded()
        return min(max(raw, parameters.minimumWalk), parameters.maximumWalk)
    }

    /// Number of paces to walk during one hold ("X" in the PRD prompt).
    public static func paces(maxHold: TimeInterval, parameters: HypoxicSprintParameters = .standard) -> Int {
        let seconds = walkDuration(maxHold: maxHold, parameters: parameters)
        return max(1, Int((seconds * parameters.pacesPerSecond).rounded()))
    }

    static func clampedReps(_ reps: Int) -> Int {
        min(max(reps, HypoxicSprintParameters.repRange.lowerBound), HypoxicSprintParameters.repRange.upperBound)
    }
}

extension SessionPlan {
    /// Builds a walking hypoxic sprint plan from the user's max hold.
    public static func hypoxicSprints(maxHold: TimeInterval, parameters: HypoxicSprintParameters = .standard) -> SessionPlan {
        let reps = HypoxicSprints.clampedReps(parameters.reps)
        let walk = HypoxicSprints.walkDuration(maxHold: maxHold, parameters: parameters)
        let paces = HypoxicSprints.paces(maxHold: maxHold, parameters: parameters)
        var builder = PlanBuilder(roundCount: reps)
        builder.add(
            .prepare,
            duration: parameters.prepareDuration,
            instruction: "Find flat, safe ground away from traffic and water. Walk at an easy pace and breathe normally.",
            voicePrompt: "Get ready. Walk at an easy pace."
        )
        for rep in 1...reps {
            builder.add(
                .walkHold,
                duration: walk,
                round: rep,
                instruction: "Exhale fully, pinch your nose, and walk for \(paces) paces.",
                voicePrompt: "Exhale fully, pinch your nose, and walk \(paces) paces.",
                paces: paces
            )
            builder.add(
                .recover,
                duration: parameters.recovery,
                round: rep,
                instruction: "Release and breathe normally for one minute. Keep walking gently.",
                voicePrompt: "Breathe normally."
            )
        }
        return builder.plan(kind: .hypoxicSprints)
    }
}
