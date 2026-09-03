import XCTest
@testable import BreatheKit

final class CueSchedulerTests: XCTestCase {
    private func step(_ phase: BreathPhase, duration: TimeInterval? = 4, prompt: String? = nil, measured: Bool = false) -> SessionStep {
        SessionStep(id: 0, phase: phase, duration: duration, instruction: phase.displayName,
                    voicePrompt: prompt, isMeasured: measured)
    }

    func testStepStartCuesByPhase() {
        let scheduler = CueScheduler.standard
        XCTAssertEqual(scheduler.cues(for: .stepBegan(index: 1, step: step(.inhale))),
                       [.tone(.inhale), .haptic(.medium), .speak("Inhale")])
        XCTAssertEqual(scheduler.cues(for: .stepBegan(index: 1, step: step(.exhale))),
                       [.tone(.exhale), .haptic(.medium), .speak("Exhale")])
        XCTAssertEqual(scheduler.cues(for: .stepBegan(index: 1, step: step(.holdFull))),
                       [.tone(.hold), .haptic(.heavy), .speak("Hold")])
        XCTAssertEqual(scheduler.cues(for: .stepBegan(index: 1, step: step(.recover, prompt: "Breathe"))),
                       [.tone(.release), .haptic(.light), .speak("Breathe")])
        XCTAssertEqual(scheduler.cues(for: .stepBegan(index: 0, step: step(.prepare, prompt: "Get ready"))),
                       [.haptic(.light), .speak("Get ready")], "no tone for the prepare step")
        XCTAssertEqual(scheduler.cues(for: .stepBegan(index: 1, step: step(.walkHold, prompt: "Walk 45 paces"))),
                       [.tone(.hold), .haptic(.heavy), .speak("Walk 45 paces")])
    }

    func testCountdownSpeaksOnlyBeforeHolds() {
        let scheduler = CueScheduler.standard
        let beforeHold = SessionEvent.countdown(secondsRemaining: 3, step: step(.recover, duration: 60), nextStep: step(.holdFull))
        XCTAssertEqual(scheduler.cues(for: beforeHold), [.tone(.tick), .haptic(.tick), .speak("3")])
        let beforeInhale = SessionEvent.countdown(secondsRemaining: 2, step: step(.prepare, duration: 10), nextStep: step(.inhale))
        XCTAssertEqual(scheduler.cues(for: beforeInhale), [.tone(.tick), .haptic(.tick)])
        let last = SessionEvent.countdown(secondsRemaining: 1, step: step(.recover, duration: 60), nextStep: nil)
        XCTAssertEqual(scheduler.cues(for: last), [.tone(.tick), .haptic(.tick)])

        var quietCountdown = CueScheduler.standard
        quietCountdown.speaksCountdownBeforeHolds = false
        XCTAssertEqual(quietCountdown.cues(for: beforeHold), [.tone(.tick), .haptic(.tick)])
    }

    func testMeasuredStepEndAnnouncesResult() {
        let scheduler = CueScheduler.standard
        let measured = SessionEvent.stepEnded(index: 3, step: step(.holdEmpty, duration: nil, measured: true), elapsed: 34.4, wasSkipped: false)
        XCTAssertEqual(scheduler.cues(for: measured), [.tone(.chime), .haptic(.success), .speak("Recorded 34 s.")])
        let ordinary = SessionEvent.stepEnded(index: 3, step: step(.holdFull), elapsed: 4, wasSkipped: false)
        XCTAssertEqual(scheduler.cues(for: ordinary), [])
    }

    func testLifecycleCues() {
        let scheduler = CueScheduler.standard
        XCTAssertEqual(scheduler.cues(for: .started), [])
        XCTAssertEqual(scheduler.cues(for: .paused), [.haptic(.light), .speak("Paused")])
        XCTAssertEqual(scheduler.cues(for: .resumed), [.haptic(.light), .speak("Resuming")])

        let summary = SessionSummary(kind: .co2Table, title: "CO2 Table", totalElapsed: 735, plannedDuration: 735,
                                     completedSteps: 13, stepCount: 13, holdDurations: [], measuredSeconds: nil, wasAborted: false)
        XCTAssertEqual(scheduler.cues(for: .completed(summary)),
                       [.tone(.chime), .haptic(.success), .speak("Session complete. 12 min 15 s of training. Well done.")])

        let assessment = SessionSummary(kind: .boltAssessment, title: "BOLT", totalElapsed: 50, plannedDuration: 16,
                                        completedSteps: 4, stepCount: 4, holdDurations: [34], measuredSeconds: 34, wasAborted: false)
        XCTAssertEqual(scheduler.cues(for: .completed(assessment)).last, .speak("Assessment complete. 34 s."))
        XCTAssertEqual(scheduler.cues(for: .aborted(assessment)), [.haptic(.warning)])
    }

    func testChannelsCanBeDisabledIndependently() {
        let event = SessionEvent.stepBegan(index: 1, step: step(.inhale))
        XCTAssertEqual(CueScheduler.silent.cues(for: event), [])
        XCTAssertEqual(CueScheduler(voiceEnabled: false).cues(for: event), [.tone(.inhale), .haptic(.medium)])
        XCTAssertEqual(CueScheduler(tonesEnabled: false).cues(for: event), [.haptic(.medium), .speak("Inhale")])
        XCTAssertEqual(CueScheduler(hapticsEnabled: false).cues(for: event), [.tone(.inhale), .speak("Inhale")])
    }

    func testEveryPhaseHasAHapticAndMostHaveATone() {
        for phase in BreathPhase.allCases {
            _ = CueScheduler.haptic(for: phase)
            let tone = CueScheduler.tone(for: phase)
            XCTAssertEqual(tone == nil, phase == .prepare || phase == .complete, "\(phase)")
        }
    }
}
