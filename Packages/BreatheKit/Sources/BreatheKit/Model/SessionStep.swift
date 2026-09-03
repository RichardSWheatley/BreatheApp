import Foundation

/// One timed (or open-ended) instruction inside a `SessionPlan`.
public struct SessionStep: Codable, Sendable, Hashable, Identifiable {
    /// Position of the step in its plan (0-based). Assigned by the plan builder.
    public let id: Int
    public let phase: BreathPhase
    /// Planned length in seconds. `nil` means the step runs until the user
    /// marks it (assessment holds, the single breath count).
    public let duration: TimeInterval?
    /// 1-based round / cycle / set number, or 0 when the step is not part of one.
    public let round: Int
    /// Total number of rounds in the plan (0 when not applicable).
    public let roundCount: Int
    /// Full instruction shown on screen ("Exhale fully, pinch your nose and walk 45 paces").
    public let instruction: String
    /// Short prompt spoken aloud at the start of the step ("Inhale", "Hold").
    public let voicePrompt: String
    /// Walking target for hypoxic sprint holds.
    public let paces: Int?
    /// 1-based repetition inside a set (inspiratory muscle training).
    public let rep: Int?
    /// Repetitions per set (inspiratory muscle training).
    public let repCount: Int?
    /// When `true`, the elapsed time of this step is the assessment result.
    public let isMeasured: Bool

    public init(
        id: Int,
        phase: BreathPhase,
        duration: TimeInterval?,
        round: Int = 0,
        roundCount: Int = 0,
        instruction: String,
        voicePrompt: String? = nil,
        paces: Int? = nil,
        rep: Int? = nil,
        repCount: Int? = nil,
        isMeasured: Bool = false
    ) {
        self.id = id
        self.phase = phase
        self.duration = duration
        self.round = round
        self.roundCount = roundCount
        self.instruction = instruction
        self.voicePrompt = voicePrompt ?? phase.displayName
        self.paces = paces
        self.rep = rep
        self.repCount = repCount
        self.isMeasured = isMeasured
    }

    /// `true` for steps that only end when the user marks them.
    public var isOpenEnded: Bool { duration == nil }
}
