import Foundation

/// An ordered, fully resolved list of steps for one session.
///
/// Plans are pure data: generators produce them from the user's baselines and
/// a parameter struct, the engine executes them, and the UI renders them.
public struct SessionPlan: Codable, Sendable, Hashable {
    public let kind: SessionKind
    public let title: String
    public let steps: [SessionStep]
    /// Number of rounds / cycles / sets / reps the plan is organised in.
    public let roundCount: Int

    public init(kind: SessionKind, title: String? = nil, steps: [SessionStep], roundCount: Int) {
        self.kind = kind
        self.title = title ?? kind.title
        self.steps = steps
        self.roundCount = roundCount
    }

    /// Sum of all timed steps. Open-ended steps contribute nothing.
    public var plannedDuration: TimeInterval {
        steps.reduce(0) { $0 + ($1.duration ?? 0) }
    }

    /// Steps during which the user holds their breath.
    public var holdSteps: [SessionStep] {
        steps.filter { $0.phase.isHold }
    }

    /// `true` when at least one step waits for the user to mark it.
    public var isOpenEnded: Bool {
        steps.contains { $0.isOpenEnded }
    }

    /// The step whose elapsed time is the assessment result, if any.
    public var measuredStep: SessionStep? {
        steps.first { $0.isMeasured }
    }

    public var stepCount: Int { steps.count }
}

/// Convenience builder that assigns step ids in order.
struct PlanBuilder {
    private(set) var steps: [SessionStep] = []
    let roundCount: Int

    init(roundCount: Int) {
        self.roundCount = roundCount
    }

    mutating func add(
        _ phase: BreathPhase,
        duration: TimeInterval?,
        round: Int = 0,
        instruction: String,
        voicePrompt: String? = nil,
        paces: Int? = nil,
        rep: Int? = nil,
        repCount: Int? = nil,
        isMeasured: Bool = false
    ) {
        steps.append(
            SessionStep(
                id: steps.count,
                phase: phase,
                duration: duration,
                round: round,
                roundCount: round == 0 ? 0 : roundCount,
                instruction: instruction,
                voicePrompt: voicePrompt,
                paces: paces,
                rep: rep,
                repCount: repCount,
                isMeasured: isMeasured
            )
        )
    }

    func plan(kind: SessionKind, title: String? = nil) -> SessionPlan {
        SessionPlan(kind: kind, title: title, steps: steps, roundCount: roundCount)
    }
}
