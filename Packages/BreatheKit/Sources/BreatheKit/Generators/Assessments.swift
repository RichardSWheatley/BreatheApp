import Foundation

/// Parameters shared by the three baseline assessments (PRD §3).
public struct AssessmentParameters: Codable, Sendable, Hashable {
    public var prepareDuration: TimeInterval
    /// Length of the "normal" inhale / exhale that precedes the BOLT hold.
    public var normalBreath: TimeInterval
    /// Length of each deep breath before the max hold.
    public var deepBreath: TimeInterval

    public init(prepareDuration: TimeInterval = 10, normalBreath: TimeInterval = 3, deepBreath: TimeInterval = 5) {
        self.prepareDuration = prepareDuration
        self.normalBreath = normalBreath
        self.deepBreath = deepBreath
    }

    public static let standard = AssessmentParameters()
}

extension SessionPlan {
    /// Body Oxygen Level Test: normal inhale, normal exhale, pinch nose, stop at
    /// the first physical urge to breathe or swallow.
    public static func boltAssessment(parameters: AssessmentParameters = .standard) -> SessionPlan {
        var builder = PlanBuilder(roundCount: 1)
        builder.add(.prepare, duration: parameters.prepareDuration,
                    instruction: "Rest quietly and breathe normally through your nose.", voicePrompt: "Rest quietly")
        builder.add(.inhale, duration: parameters.normalBreath,
                    instruction: "Take a normal, quiet inhale.", voicePrompt: "Normal inhale")
        builder.add(.exhale, duration: parameters.normalBreath,
                    instruction: "Let a normal, quiet exhale out.", voicePrompt: "Normal exhale")
        builder.add(.holdEmpty, duration: nil,
                    instruction: "Pinch your nose. Tap Stop at the first physical urge to swallow or breathe.",
                    voicePrompt: "Pinch your nose and hold", isMeasured: true)
        return builder.plan(kind: .boltAssessment)
    }

    /// Maximum static apnea: three deep breaths, fill to 100%, hold until forced to exhale.
    public static func maxHoldAssessment(parameters: AssessmentParameters = .standard) -> SessionPlan {
        var builder = PlanBuilder(roundCount: 3)
        builder.add(.prepare, duration: parameters.prepareDuration,
                    instruction: "Sit or lie down somewhere safe. Never do this in water.", voicePrompt: "Get ready")
        for breath in 1...3 {
            let isLast = breath == 3
            builder.add(.inhale, duration: parameters.deepBreath, round: breath,
                        instruction: isLast ? "Final inhale: fill your lungs to 100%." : "Deep breath in.",
                        voicePrompt: isLast ? "Fill your lungs completely" : "Deep breath in")
            if !isLast {
                builder.add(.exhale, duration: parameters.deepBreath, round: breath,
                            instruction: "Long, slow breath out.", voicePrompt: "Breathe out")
            }
        }
        builder.add(.holdFull, duration: nil, round: 3,
                    instruction: "Hold. Tap Stop when you are forced to exhale.",
                    voicePrompt: "Hold", isMeasured: true)
        return builder.plan(kind: .maxHoldAssessment)
    }

    /// Single breath count: inhale fully, count aloud steadily on one exhale.
    public static func breathCountAssessment(parameters: AssessmentParameters = .standard) -> SessionPlan {
        var builder = PlanBuilder(roundCount: 1)
        builder.add(.prepare, duration: parameters.prepareDuration,
                    instruction: "Stand or sit tall. You will count out loud at a steady pace on one breath.",
                    voicePrompt: "Get ready")
        builder.add(.inhale, duration: parameters.deepBreath,
                    instruction: "Inhale fully.", voicePrompt: "Inhale fully")
        builder.add(.countAloud, duration: nil,
                    instruction: "Count aloud: 1, 2, 3... at a steady pace. Tap Stop when your lungs are empty.",
                    voicePrompt: "Start counting", isMeasured: true)
        return builder.plan(kind: .breathCountAssessment)
    }

    /// Builds the plan for any kind from the user's baselines, using standard parameters.
    public static func standard(for kind: SessionKind, baselines: Baselines) -> SessionPlan {
        let maxHold = baselines.maxHoldSeconds ?? Progression.defaultMaxHold
        switch kind {
        case .cadence: return .cadence(bolt: baselines.boltSeconds)
        case .hypoxicSprints: return .hypoxicSprints(maxHold: maxHold)
        case .co2Table: return .co2Table(maxHold: maxHold)
        case .o2Table: return .o2Table(maxHold: maxHold)
        case .imt: return .imt()
        case .boltAssessment: return .boltAssessment()
        case .maxHoldAssessment: return .maxHoldAssessment()
        case .breathCountAssessment: return .breathCountAssessment()
        }
    }
}
