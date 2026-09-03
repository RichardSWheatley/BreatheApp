import Foundation

/// Drives a `SessionPlan` forward in time and reports what happened.
///
/// The engine is deliberately passive: it never schedules timers itself.
/// Something else (the app's session controller, the simulator, a test)
/// calls `tick()` or `advance(by:)` and receives the events produced. That
/// makes every session fully deterministic and lets the same code run at
/// real time, 1000x speed, or one step at a time.
///
/// The engine is not thread-safe. In the app it lives on the main actor.
public final class SessionEngine {
    public enum State: String, Sendable, Hashable, Codable {
        case idle, running, paused, completed, aborted
    }

    public let plan: SessionPlan
    private let clock: any SessionClock

    public private(set) var state: State = .idle
    public private(set) var stepIndex = 0
    /// Seconds into the current step.
    public private(set) var stepElapsed: TimeInterval = 0
    /// Seconds since `start()`, excluding paused time.
    public private(set) var totalElapsed: TimeInterval = 0

    /// Countdown events are only produced for steps at least this long.
    public var countdownThreshold: TimeInterval = 5

    private var lastTickTime: TimeInterval?
    private var lastCountdownIssued = Int.max
    private var timedElapsed: TimeInterval = 0
    private var holdDurations: [TimeInterval] = []
    private var measuredSeconds: TimeInterval?
    private var completedSteps = 0

    private static let epsilon: TimeInterval = 1e-9

    public init(plan: SessionPlan, clock: any SessionClock = ContinuousSessionClock()) {
        self.plan = plan
        self.clock = clock
    }

    // MARK: - Introspection

    public var isActive: Bool { state == .running || state == .paused }

    public var currentStep: SessionStep? {
        guard isActive, stepIndex < plan.steps.count else { return nil }
        return plan.steps[stepIndex]
    }

    public var nextStep: SessionStep? {
        guard isActive, stepIndex + 1 < plan.steps.count else { return nil }
        return plan.steps[stepIndex + 1]
    }

    /// 0...1 through the current timed step, `nil` when open-ended or inactive.
    public var stepProgress: Double? {
        guard let step = currentStep, let duration = step.duration, duration > 0 else { return nil }
        return min(1, stepElapsed / duration)
    }

    public var stepRemaining: TimeInterval? {
        guard let step = currentStep, let duration = step.duration else { return nil }
        return max(0, duration - stepElapsed)
    }

    /// 0...1 across the session, by planned time (or by steps for untimed plans).
    public var sessionProgress: Double {
        if state == .completed { return 1 }
        let planned = plan.plannedDuration
        if planned > 0 {
            return min(1, timedElapsed / planned)
        }
        guard plan.steps.count > 0 else { return 1 }
        return min(1, Double(completedSteps) / Double(plan.steps.count))
    }

    public var fullness: Double {
        let phase: BreathPhase
        if let step = currentStep {
            phase = step.phase
        } else if state == .completed || state == .aborted {
            phase = .complete
        } else {
            phase = plan.steps.first?.phase ?? .prepare
        }
        return Pacer.fullness(phase: phase, progress: stepProgress, elapsed: stepElapsed)
    }

    public var snapshot: SessionSnapshot {
        let step = currentStep
        let phase: BreathPhase
        switch state {
        case .completed, .aborted: phase = .complete
        case .idle: phase = plan.steps.first?.phase ?? .prepare
        case .running, .paused: phase = step?.phase ?? .complete
        }
        return SessionSnapshot(
            state: state,
            kind: plan.kind,
            title: plan.title,
            stepIndex: min(stepIndex, max(plan.steps.count - 1, 0)),
            stepCount: plan.steps.count,
            step: step,
            nextStep: nextStep,
            phase: phase,
            stepElapsed: stepElapsed,
            stepDuration: step?.duration,
            stepProgress: stepProgress,
            stepRemaining: stepRemaining,
            totalElapsed: totalElapsed,
            plannedDuration: plan.plannedDuration,
            sessionProgress: sessionProgress,
            fullness: fullness
        )
    }

    public var summary: SessionSummary {
        SessionSummary(
            kind: plan.kind,
            title: plan.title,
            totalElapsed: totalElapsed,
            plannedDuration: plan.plannedDuration,
            completedSteps: completedSteps,
            stepCount: plan.steps.count,
            holdDurations: holdDurations,
            measuredSeconds: measuredSeconds,
            wasAborted: state == .aborted
        )
    }

    // MARK: - Control

    /// Begins the session. Returns `.started` followed by the first `.stepBegan`
    /// (or `.completed` immediately for an empty plan).
    @discardableResult
    public func start() -> [SessionEvent] {
        guard state == .idle else { return [] }
        state = .running
        lastTickTime = clock.now
        stepIndex = 0
        stepElapsed = 0
        lastCountdownIssued = Int.max
        var events: [SessionEvent] = [.started]
        if plan.steps.isEmpty {
            state = .completed
            events.append(.completed(summary))
        } else {
            events.append(.stepBegan(index: 0, step: plan.steps[0]))
        }
        return events
    }

    /// Advances by however much clock time has passed since the last tick.
    @discardableResult
    public func tick() -> [SessionEvent] {
        guard state == .running else { return [] }
        let now = clock.now
        let delta = max(0, now - (lastTickTime ?? now))
        lastTickTime = now
        return advance(by: delta)
    }

    /// Advances by an explicit amount of time, crossing as many step
    /// boundaries as needed. Open-ended steps absorb all remaining time.
    @discardableResult
    public func advance(by delta: TimeInterval) -> [SessionEvent] {
        guard state == .running, delta > 0 else { return [] }
        var remaining = delta
        var events: [SessionEvent] = []

        while remaining > 0, state == .running, stepIndex < plan.steps.count {
            let step = plan.steps[stepIndex]
            guard let duration = step.duration else {
                stepElapsed += remaining
                totalElapsed += remaining
                remaining = 0
                break
            }

            let timeLeft = duration - stepElapsed
            if remaining + Self.epsilon >= timeLeft {
                let consumed = max(0, timeLeft)
                stepElapsed = duration
                totalElapsed += consumed
                timedElapsed += consumed
                remaining -= consumed
                events.append(contentsOf: finishCurrentStep(elapsed: duration, wasSkipped: false))
            } else {
                stepElapsed += remaining
                totalElapsed += remaining
                timedElapsed += remaining
                remaining = 0
                if let countdown = countdownEvent(step: step, duration: duration) {
                    events.append(countdown)
                }
            }
        }
        return events
    }

    /// The user's "I'm done" action. Ends an open-ended step (recording its
    /// elapsed time) or skips the rest of a timed step.
    @discardableResult
    public func mark() -> [SessionEvent] {
        guard state == .running, let step = currentStep else { return [] }
        // Skipping a timed step leaves its unused time out of the planned-time
        // progress; open-ended steps simply record how long they ran.
        return finishCurrentStep(elapsed: stepElapsed, wasSkipped: !step.isOpenEnded)
    }

    @discardableResult
    public func pause() -> [SessionEvent] {
        guard state == .running else { return [] }
        state = .paused
        return [.paused]
    }

    @discardableResult
    public func resume() -> [SessionEvent] {
        guard state == .paused else { return [] }
        state = .running
        lastTickTime = clock.now
        return [.resumed]
    }

    @discardableResult
    public func abort() -> [SessionEvent] {
        guard isActive else { return [] }
        state = .aborted
        return [.aborted(summary)]
    }

    // MARK: - Internals

    private func finishCurrentStep(elapsed: TimeInterval, wasSkipped: Bool) -> [SessionEvent] {
        let index = stepIndex
        let step = plan.steps[index]
        var events: [SessionEvent] = []

        if step.phase.isHold {
            holdDurations.append(elapsed)
        }
        if step.isMeasured, measuredSeconds == nil {
            measuredSeconds = elapsed
        }
        completedSteps += 1
        events.append(.stepEnded(index: index, step: step, elapsed: elapsed, wasSkipped: wasSkipped))

        stepIndex += 1
        stepElapsed = 0
        lastCountdownIssued = Int.max

        if stepIndex >= plan.steps.count {
            state = .completed
            events.append(.completed(summary))
        } else {
            events.append(.stepBegan(index: stepIndex, step: plan.steps[stepIndex]))
        }
        return events
    }

    private func countdownEvent(step: SessionStep, duration: TimeInterval) -> SessionEvent? {
        guard duration >= countdownThreshold else { return nil }
        let left = Int((duration - stepElapsed).rounded(.up))
        guard (1...3).contains(left), left < lastCountdownIssued else { return nil }
        lastCountdownIssued = left
        return .countdown(secondsRemaining: left, step: step, nextStep: nextStep)
    }
}
