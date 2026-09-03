import Foundation

/// Parameters for Inspiratory Muscle Training (PRD §4D): 3 sets of 15
/// forceful inhalations against manual resistance.
public struct IMTParameters: Codable, Sendable, Hashable {
    public var sets: Int
    public var reps: Int
    public var inhale: TimeInterval
    public var exhale: TimeInterval
    public var restBetweenSets: TimeInterval
    public var prepareDuration: TimeInterval

    public init(
        sets: Int = 3,
        reps: Int = 15,
        inhale: TimeInterval = 2,
        exhale: TimeInterval = 2,
        restBetweenSets: TimeInterval = 60,
        prepareDuration: TimeInterval = 10
    ) {
        self.sets = sets
        self.reps = reps
        self.inhale = inhale
        self.exhale = exhale
        self.restBetweenSets = restBetweenSets
        self.prepareDuration = prepareDuration
    }

    public static let standard = IMTParameters()
    public static let setRange = 1...6
    public static let repRange = 5...30
}

extension SessionPlan {
    /// Builds an IMT plan. Each rep is a resisted inhale followed by a relaxed exhale.
    public static func imt(parameters: IMTParameters = .standard) -> SessionPlan {
        let sets = min(max(parameters.sets, IMTParameters.setRange.lowerBound), IMTParameters.setRange.upperBound)
        let reps = min(max(parameters.reps, IMTParameters.repRange.lowerBound), IMTParameters.repRange.upperBound)
        var builder = PlanBuilder(roundCount: sets)
        builder.add(
            .prepare,
            duration: parameters.prepareDuration,
            instruction: "Purse your lips tightly (or breathe through a straw) to create resistance. Sit tall.",
            voicePrompt: "Get ready"
        )
        for set in 1...sets {
            for rep in 1...reps {
                builder.add(
                    .resistedInhale,
                    duration: parameters.inhale,
                    round: set,
                    instruction: "Inhale hard against the resistance. Drive with your diaphragm.",
                    voicePrompt: rep == 1 ? "Set \(set). Inhale" : "Inhale",
                    rep: rep,
                    repCount: reps
                )
                builder.add(
                    .exhale,
                    duration: parameters.exhale,
                    round: set,
                    instruction: "Relax and let the air out.",
                    voicePrompt: "Exhale",
                    rep: rep,
                    repCount: reps
                )
            }
            if set < sets {
                builder.add(
                    .rest,
                    duration: parameters.restBetweenSets,
                    round: set,
                    instruction: "Rest. Breathe normally before the next set.",
                    voicePrompt: "Rest"
                )
            }
        }
        return builder.plan(kind: .imt)
    }
}
