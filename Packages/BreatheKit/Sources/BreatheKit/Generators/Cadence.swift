import Foundation

/// Parameters for the CO2 Tolerance Builder (PRD §4A).
///
/// Base ratio is 4 s inhale, 6 s hold, 4 s exhale, 6 s hold. The hold
/// durations scale upward with the user's BOLT score via `Progression`.
public struct CadenceParameters: Codable, Sendable, Hashable {
    public var rounds: Int
    public var inhale: TimeInterval
    public var exhale: TimeInterval
    /// Explicit hold length. When `nil` the hold is derived from the BOLT score.
    public var holdOverride: TimeInterval?
    public var prepareDuration: TimeInterval

    public init(
        rounds: Int = 10,
        inhale: TimeInterval = 4,
        exhale: TimeInterval = 4,
        holdOverride: TimeInterval? = nil,
        prepareDuration: TimeInterval = 10
    ) {
        self.rounds = rounds
        self.inhale = inhale
        self.exhale = exhale
        self.holdOverride = holdOverride
        self.prepareDuration = prepareDuration
    }

    public static let standard = CadenceParameters()
    public static let roundRange = 1...40
}

extension SessionPlan {
    /// Builds a cadence-breathing plan. Holds scale with the BOLT score.
    public static func cadence(bolt: TimeInterval?, parameters: CadenceParameters = .standard) -> SessionPlan {
        let rounds = min(max(parameters.rounds, CadenceParameters.roundRange.lowerBound), CadenceParameters.roundRange.upperBound)
        let hold = parameters.holdOverride ?? Progression.cadenceHold(bolt: bolt)
        var builder = PlanBuilder(roundCount: rounds)
        builder.add(
            .prepare,
            duration: parameters.prepareDuration,
            instruction: "Sit tall. Follow the circle: it grows as you inhale and shrinks as you exhale.",
            voicePrompt: "Get ready"
        )
        for round in 1...rounds {
            builder.add(.inhale, duration: parameters.inhale, round: round,
                        instruction: "Inhale slowly through your nose.", voicePrompt: "Inhale")
            builder.add(.holdFull, duration: hold, round: round,
                        instruction: "Hold with full lungs. Stay relaxed.", voicePrompt: "Hold")
            builder.add(.exhale, duration: parameters.exhale, round: round,
                        instruction: "Exhale gently and completely.", voicePrompt: "Exhale")
            builder.add(.holdEmpty, duration: hold, round: round,
                        instruction: "Hold with empty lungs. Notice the air hunger and stay calm.", voicePrompt: "Hold")
        }
        return builder.plan(kind: .cadence)
    }
}
