import BreatheKit
import Foundation
import Observation

/// Runs one session on the main actor: ticks the engine on a timer, routes
/// events to cues, tracks paces during walking holds, and publishes a
/// snapshot the views render.
@Observable
@MainActor
final class SessionController: Identifiable {
    let id = UUID()
    let plan: SessionPlan
    private(set) var snapshot: SessionSnapshot
    private(set) var summary: SessionSummary?
    private(set) var startedAt: Date?
    /// Live pace count during a walking hold (0 when the pedometer is unavailable).
    private(set) var walkPaces = 0

    private let engine: SessionEngine
    private let scheduler: CueScheduler
    private let cueSink: any CueSink
    private let pedometer: PedometerService?
    private let tickInterval: Duration
    private var tickTask: Task<Void, Never>?

    init(
        plan: SessionPlan,
        clock: any SessionClock = ContinuousSessionClock(),
        scheduler: CueScheduler = .standard,
        cueSink: any CueSink,
        pedometer: PedometerService? = nil,
        tickInterval: Duration = .milliseconds(50)
    ) {
        self.plan = plan
        self.scheduler = scheduler
        self.cueSink = cueSink
        self.pedometer = pedometer
        self.tickInterval = tickInterval
        engine = SessionEngine(plan: plan, clock: clock)
        snapshot = engine.snapshot
    }

    var state: SessionEngine.State { snapshot.state }
    var isFinished: Bool { summary != nil }

    func start() {
        guard engine.state == .idle else { return }
        startedAt = Date()
        cueSink.sessionWillStart()
        dispatch(engine.start())
        refresh()
        finishIfNeeded()
        startTicking()
    }

    func pause() {
        dispatch(engine.pause())
        refresh()
    }

    func resume() {
        dispatch(engine.resume())
        refresh()
    }

    func togglePause() {
        if snapshot.state == .paused { resume() } else { pause() }
    }

    /// Ends the current step: records an open-ended hold, skips a timed step.
    func mark() {
        dispatch(engine.mark())
        refresh()
        finishIfNeeded()
    }

    /// Abandons the session (no-op once finished).
    func end() {
        if engine.isActive {
            dispatch(engine.abort())
        }
        refresh()
        finishIfNeeded()
    }

    /// Performs one engine tick. The internal timer calls this; tests call it directly.
    func tickNow() {
        dispatch(engine.tick())
        refresh()
        finishIfNeeded()
    }

    // MARK: - Internals

    private func startTicking() {
        tickTask?.cancel()
        let interval = tickInterval
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self, !Task.isCancelled else { return }
                self.tickNow()
            }
        }
    }

    private func refresh() {
        snapshot = engine.snapshot
    }

    private func finishIfNeeded() {
        guard summary == nil, engine.state == .completed || engine.state == .aborted else { return }
        summary = engine.summary
        tickTask?.cancel()
        tickTask = nil
        pedometer?.stop()
        cueSink.sessionDidEnd()
    }

    private func dispatch(_ events: [SessionEvent]) {
        for event in events {
            for cue in scheduler.cues(for: event) {
                cueSink.play(cue)
            }
            switch event {
            case .stepBegan(_, let step) where step.phase == .walkHold:
                beginPaceCounting(target: step.paces)
            case .stepEnded(_, let step, _, _) where step.phase == .walkHold:
                pedometer?.stop()
            default:
                break
            }
        }
    }

    private func beginPaceCounting(target: Int?) {
        walkPaces = 0
        guard let target, let pedometer else { return }
        pedometer.startCounting { [weak self] count in
            guard let self, self.snapshot.phase == .walkHold, self.snapshot.isRunning else { return }
            self.walkPaces = count
            if count >= target {
                self.mark()
            }
        }
    }
}
