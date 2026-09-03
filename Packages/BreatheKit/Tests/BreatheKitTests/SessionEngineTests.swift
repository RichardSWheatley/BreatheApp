import XCTest
@testable import BreatheKit

final class SessionEngineTests: XCTestCase {
    private func plan(_ phases: [(BreathPhase, TimeInterval?)], kind: SessionKind = .cadence) -> SessionPlan {
        var builder = PlanBuilder(roundCount: 1)
        for (phase, duration) in phases {
            builder.add(phase, duration: duration, round: 1, instruction: phase.displayName,
                        isMeasured: duration == nil)
        }
        return builder.plan(kind: kind)
    }

    func testStartEmitsStartedAndFirstStep() {
        let engine = SessionEngine(plan: plan([(.inhale, 4), (.exhale, 4)]), clock: ManualClock())
        XCTAssertEqual(engine.state, .idle)
        XCTAssertTrue(engine.tick().isEmpty)

        let events = engine.start()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0], .started)
        guard case .stepBegan(let index, let step) = events[1] else { return XCTFail("expected stepBegan") }
        XCTAssertEqual(index, 0)
        XCTAssertEqual(step.phase, .inhale)
        XCTAssertEqual(engine.state, .running)
        XCTAssertTrue(engine.start().isEmpty, "second start is a no-op")
    }

    func testEmptyPlanCompletesImmediately() {
        let engine = SessionEngine(plan: SessionPlan(kind: .cadence, steps: [], roundCount: 0), clock: ManualClock())
        let events = engine.start()
        XCTAssertEqual(engine.state, .completed)
        XCTAssertEqual(events.count, 2)
        guard case .completed(let summary) = events[1] else { return XCTFail("expected completed") }
        XCTAssertTrue(summary.isComplete)
    }

    func testAdvanceCrossesStepBoundaries() {
        let engine = SessionEngine(plan: plan([(.inhale, 10), (.holdFull, 5), (.exhale, 10)]), clock: ManualClock())
        engine.start()

        XCTAssertTrue(engine.advance(by: 4).isEmpty)
        XCTAssertEqual(engine.stepElapsed, 4)
        XCTAssertEqual(engine.stepRemaining, 6)
        XCTAssertEqual(engine.stepProgress!, 0.4, accuracy: 1e-9)

        let events = engine.advance(by: 6)
        XCTAssertEqual(events.count, 2)
        guard case .stepEnded(let endedIndex, _, let elapsed, let skipped) = events[0] else { return XCTFail() }
        XCTAssertEqual(endedIndex, 0)
        XCTAssertEqual(elapsed, 10)
        XCTAssertFalse(skipped)
        guard case .stepBegan(let beganIndex, let step) = events[1] else { return XCTFail() }
        XCTAssertEqual(beganIndex, 1)
        XCTAssertEqual(step.phase, .holdFull)
        XCTAssertEqual(engine.stepElapsed, 0)
        XCTAssertEqual(engine.totalElapsed, 10)
    }

    func testLargeAdvanceCrossesSeveralStepsAndCompletes() {
        let engine = SessionEngine(plan: plan([(.inhale, 10), (.holdFull, 10), (.exhale, 10)]), clock: ManualClock())
        engine.start()
        let events = engine.advance(by: 100)
        let ended = events.filter { if case .stepEnded = $0 { return true } else { return false } }
        let began = events.filter { if case .stepBegan = $0 { return true } else { return false } }
        XCTAssertEqual(ended.count, 3)
        XCTAssertEqual(began.count, 2)
        XCTAssertEqual(engine.state, .completed)
        XCTAssertEqual(engine.totalElapsed, 30, "time past the end of the plan is not counted")
        guard case .completed(let summary)? = events.last else { return XCTFail("expected completed last") }
        XCTAssertEqual(summary.completedSteps, 3)
        XCTAssertEqual(summary.holdDurations, [10])
        XCTAssertEqual(summary.totalElapsed, 30)
        XCTAssertTrue(summary.isComplete)
        XCTAssertTrue(engine.advance(by: 1).isEmpty)
        XCTAssertEqual(engine.sessionProgress, 1)
    }

    func testCountdownFiresOnceForEachOfLastThreeSeconds() {
        let engine = SessionEngine(plan: plan([(.recover, 10), (.holdFull, 4)]), clock: ManualClock())
        engine.start()
        var countdowns: [Int] = []
        for _ in 0..<100 {
            for event in engine.advance(by: 0.1) {
                if case .countdown(let n, let step, let next) = event {
                    countdowns.append(n)
                    XCTAssertEqual(step.phase, .recover)
                    XCTAssertEqual(next?.phase, .holdFull)
                }
            }
        }
        XCTAssertEqual(countdowns, [3, 2, 1])

        // The 4 s hold is below the countdown threshold: no countdown events.
        var later: [Int] = []
        for _ in 0..<40 {
            for event in engine.advance(by: 0.1) {
                if case .countdown(let n, _, _) = event { later.append(n) }
            }
        }
        XCTAssertEqual(later, [])
        XCTAssertEqual(engine.state, .completed)
    }

    func testCountdownSkipsValuesWhenTimeJumps() {
        let engine = SessionEngine(plan: plan([(.recover, 10)]), clock: ManualClock())
        engine.start()
        engine.advance(by: 7.5)      // 2.5 s left → "3"
        let events = engine.advance(by: 1.6) // 0.9 s left → "1" (skips 2)
        let values = events.compactMap { event -> Int? in
            if case .countdown(let n, _, _) = event { return n }
            return nil
        }
        XCTAssertEqual(values, [1])
    }

    func testOpenEndedStepAbsorbsTimeUntilMarked() {
        let engine = SessionEngine(plan: plan([(.inhale, 2), (.holdEmpty, nil)], kind: .boltAssessment), clock: ManualClock())
        engine.start()
        engine.advance(by: 2)
        XCTAssertEqual(engine.currentStep?.phase, .holdEmpty)
        XCTAssertNil(engine.stepProgress)
        XCTAssertNil(engine.stepRemaining)

        let quiet = engine.advance(by: 34.2)
        XCTAssertTrue(quiet.isEmpty)
        XCTAssertEqual(engine.stepElapsed, 34.2, accuracy: 1e-9)

        let events = engine.mark()
        guard case .stepEnded(_, let step, let elapsed, let skipped) = events[0] else { return XCTFail() }
        XCTAssertEqual(step.phase, .holdEmpty)
        XCTAssertEqual(elapsed, 34.2, accuracy: 1e-9)
        XCTAssertFalse(skipped)
        XCTAssertEqual(engine.state, .completed)
        XCTAssertEqual(engine.summary.measuredSeconds!, 34.2, accuracy: 1e-9)
        XCTAssertEqual(engine.summary.holdDurations.count, 1)
        XCTAssertEqual(engine.summary.totalElapsed, 36.2, accuracy: 1e-9)
    }

    func testMarkSkipsATimedStep() {
        let engine = SessionEngine(plan: plan([(.recover, 60), (.holdFull, 10)]), clock: ManualClock())
        engine.start()
        engine.advance(by: 15)
        let events = engine.mark()
        guard case .stepEnded(let index, _, let elapsed, let skipped) = events[0] else { return XCTFail() }
        XCTAssertEqual(index, 0)
        XCTAssertEqual(elapsed, 15)
        XCTAssertTrue(skipped)
        XCTAssertEqual(engine.currentStep?.phase, .holdFull)
        XCTAssertEqual(engine.sessionProgress, 15.0 / 70.0, accuracy: 1e-9)
    }

    func testTickUsesClockAndPauseFreezesTime() {
        let clock = ManualClock()
        let engine = SessionEngine(plan: plan([(.recover, 60)]), clock: clock)
        engine.start()

        clock.advance(by: 1)
        engine.tick()
        XCTAssertEqual(engine.stepElapsed, 1, accuracy: 1e-9)

        XCTAssertEqual(engine.pause(), [.paused])
        XCTAssertEqual(engine.state, .paused)
        clock.advance(by: 10)
        XCTAssertTrue(engine.tick().isEmpty)
        XCTAssertTrue(engine.advance(by: 5).isEmpty)
        XCTAssertEqual(engine.stepElapsed, 1, accuracy: 1e-9, "paused time is not counted")
        XCTAssertTrue(engine.mark().isEmpty, "mark is ignored while paused")

        XCTAssertEqual(engine.resume(), [.resumed])
        engine.tick()
        XCTAssertEqual(engine.stepElapsed, 1, accuracy: 1e-9, "no jump on resume")
        clock.advance(by: 1)
        engine.tick()
        XCTAssertEqual(engine.stepElapsed, 2, accuracy: 1e-9)
        XCTAssertTrue(engine.resume().isEmpty)
    }

    func testAbortProducesSummaryAndStopsEngine() {
        let engine = SessionEngine(plan: plan([(.inhale, 4), (.holdFull, 6)]), clock: ManualClock())
        engine.start()
        engine.advance(by: 5)
        let events = engine.abort()
        guard case .aborted(let summary)? = events.first else { return XCTFail() }
        XCTAssertTrue(summary.wasAborted)
        XCTAssertFalse(summary.isComplete)
        XCTAssertEqual(summary.completedSteps, 1)
        XCTAssertEqual(summary.completionFraction, 0.5)
        XCTAssertEqual(engine.state, .aborted)
        XCTAssertTrue(engine.tick().isEmpty)
        XCTAssertTrue(engine.abort().isEmpty)
        XCTAssertNil(engine.currentStep)
    }

    func testSnapshotReflectsCurrentMoment() {
        let engine = SessionEngine(plan: plan([(.inhale, 4), (.holdFull, 6)]), clock: ManualClock())
        let idle = engine.snapshot
        XCTAssertEqual(idle.state, .idle)
        XCTAssertEqual(idle.phase, .inhale)
        XCTAssertEqual(idle.fullness, 0)

        engine.start()
        engine.advance(by: 2)
        let mid = engine.snapshot
        XCTAssertEqual(mid.phase, .inhale)
        XCTAssertEqual(mid.stepElapsed, 2)
        XCTAssertEqual(mid.stepRemaining, 2)
        XCTAssertEqual(mid.stepProgress!, 0.5, accuracy: 1e-9)
        XCTAssertEqual(mid.fullness, 0.5, accuracy: 1e-9)
        XCTAssertEqual(mid.nextStep?.phase, .holdFull)
        XCTAssertEqual(mid.round, 1)
        XCTAssertEqual(mid.sessionProgress, 0.2, accuracy: 1e-9)

        engine.advance(by: 2)
        XCTAssertEqual(engine.snapshot.phase, .holdFull)
        XCTAssertEqual(engine.snapshot.fullness, 1)
        XCTAssertNil(engine.snapshot.nextStep)

        engine.advance(by: 6)
        let done = engine.snapshot
        XCTAssertEqual(done.state, .completed)
        XCTAssertEqual(done.phase, .complete)
        XCTAssertNil(done.step)
        XCTAssertEqual(done.sessionProgress, 1)
    }

    func testScaledClockRunsFaster() {
        let base = ManualClock()
        let engine = SessionEngine(plan: plan([(.recover, 60)]), clock: ScaledSessionClock(base: base, scale: 10))
        engine.start()
        base.advance(by: 1)
        engine.tick()
        XCTAssertEqual(engine.stepElapsed, 10, accuracy: 1e-9)
    }

    func testEveryStandardPlanRunsToCompletionUnderTicks() {
        let baselines = Baselines(boltSeconds: 31, maxHoldSeconds: 90, breathCountSeconds: 30)
        for kind in SessionKind.allCases {
            let plan = SessionPlan.standard(for: kind, baselines: baselines)
            let clock = ManualClock()
            let engine = SessionEngine(plan: plan, clock: clock)
            var began: [Int] = []
            var ended: [Int] = []
            var completions = 0
            var openEndedTime: TimeInterval = 0

            func record(_ events: [SessionEvent]) {
                for event in events {
                    switch event {
                    case .stepBegan(let index, _): began.append(index)
                    case .stepEnded(let index, _, _, let skipped):
                        ended.append(index)
                        XCTAssertFalse(skipped)
                    case .completed: completions += 1
                    default: break
                    }
                }
            }

            record(engine.start())
            var iterations = 0
            while engine.state == .running, iterations < 200_000 {
                iterations += 1
                clock.advance(by: 0.25)
                record(engine.tick())
                if engine.currentStep?.isOpenEnded == true, engine.stepElapsed >= 30 {
                    openEndedTime += engine.stepElapsed
                    record(engine.mark())
                }
                XCTAssertTrue((0...1).contains(engine.fullness), "\(kind) fullness out of range")
            }

            XCTAssertEqual(engine.state, .completed, "\(kind) did not complete")
            XCTAssertEqual(began, Array(0..<plan.steps.count), "\(kind) steps began out of order")
            XCTAssertEqual(ended, Array(0..<plan.steps.count), "\(kind) steps ended out of order")
            XCTAssertEqual(completions, 1, "\(kind) completed more than once")
            XCTAssertEqual(engine.totalElapsed, plan.plannedDuration + openEndedTime, accuracy: 0.5, "\(kind) elapsed mismatch")
            XCTAssertEqual(engine.summary.holdDurations.count, plan.holdSteps.count, "\(kind) hold count")
            XCTAssertEqual(engine.summary.measuredSeconds != nil, kind.isAssessment, "\(kind) measurement")
        }
    }
}
