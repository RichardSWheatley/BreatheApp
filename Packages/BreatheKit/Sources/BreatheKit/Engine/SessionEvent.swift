import Foundation

/// What happened during a call into the engine. The app turns these into
/// audio, haptics and UI updates; tests assert on them directly.
public enum SessionEvent: Sendable, Hashable {
    case started
    case stepBegan(index: Int, step: SessionStep)
    case stepEnded(index: Int, step: SessionStep, elapsed: TimeInterval, wasSkipped: Bool)
    /// Fires once for each of the last three seconds of a timed step.
    case countdown(secondsRemaining: Int, step: SessionStep, nextStep: SessionStep?)
    case paused
    case resumed
    case completed(SessionSummary)
    case aborted(SessionSummary)
}

/// Outcome of a finished (or abandoned) session.
public struct SessionSummary: Codable, Sendable, Hashable {
    public let kind: SessionKind
    public let title: String
    public let totalElapsed: TimeInterval
    public let plannedDuration: TimeInterval
    public let completedSteps: Int
    public let stepCount: Int
    /// Actual elapsed time of every completed breath-hold step, in order.
    public let holdDurations: [TimeInterval]
    /// Assessment result, when the plan contained a measured step that completed.
    public let measuredSeconds: TimeInterval?
    public let wasAborted: Bool

    public init(
        kind: SessionKind,
        title: String,
        totalElapsed: TimeInterval,
        plannedDuration: TimeInterval,
        completedSteps: Int,
        stepCount: Int,
        holdDurations: [TimeInterval],
        measuredSeconds: TimeInterval?,
        wasAborted: Bool
    ) {
        self.kind = kind
        self.title = title
        self.totalElapsed = totalElapsed
        self.plannedDuration = plannedDuration
        self.completedSteps = completedSteps
        self.stepCount = stepCount
        self.holdDurations = holdDurations
        self.measuredSeconds = measuredSeconds
        self.wasAborted = wasAborted
    }

    public var isComplete: Bool { !wasAborted && completedSteps == stepCount }

    public var completionFraction: Double {
        stepCount == 0 ? 1 : Double(completedSteps) / Double(stepCount)
    }

    public var longestHold: TimeInterval? { holdDurations.max() }

    public var totalHoldTime: TimeInterval { holdDurations.reduce(0, +) }
}

/// Everything a view needs to render the current moment of a session.
public struct SessionSnapshot: Sendable, Hashable {
    public let state: SessionEngine.State
    public let kind: SessionKind
    public let title: String
    public let stepIndex: Int
    public let stepCount: Int
    public let step: SessionStep?
    public let nextStep: SessionStep?
    public let phase: BreathPhase
    public let stepElapsed: TimeInterval
    public let stepDuration: TimeInterval?
    /// 0...1 within a timed step; `nil` for open-ended steps.
    public let stepProgress: Double?
    public let stepRemaining: TimeInterval?
    public let totalElapsed: TimeInterval
    public let plannedDuration: TimeInterval
    /// 0...1 across the whole session.
    public let sessionProgress: Double
    /// Lung fullness 0 (empty) ... 1 (full) driving the pacer circle.
    public let fullness: Double

    public var isRunning: Bool { state == .running }
    public var isOpenEnded: Bool { step?.isOpenEnded ?? false }
    public var round: Int { step?.round ?? 0 }
    public var roundCount: Int { step?.roundCount ?? 0 }
}
