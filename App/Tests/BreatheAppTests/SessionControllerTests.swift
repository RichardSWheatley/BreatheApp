import BreatheKit
import Foundation
import Testing
@testable import BreatheApp

@MainActor
final class RecordingCueSink: CueSink {
    var cues: [Cue] = []
    var starts = 0
    var ends = 0

    func sessionWillStart() { starts += 1 }
    func sessionDidEnd() { ends += 1 }
    func play(_ cue: Cue) { cues.append(cue) }
}

@MainActor
struct SessionControllerTests {
    @Test func assessmentRecordsTheMarkedHold() {
        let clock = ManualClock()
        let sink = RecordingCueSink()
        let controller = SessionController(plan: .boltAssessment(), clock: clock, cueSink: sink)

        controller.start()
        #expect(sink.starts == 1)
        #expect(controller.state == .running)
        #expect(controller.snapshot.phase == .prepare)
        #expect(sink.cues.contains(.speak("Rest quietly")))

        clock.advance(by: 16)
        controller.tickNow()
        #expect(controller.snapshot.phase == .holdEmpty)
        #expect(controller.snapshot.isOpenEnded)
        #expect(sink.cues.contains(.tone(.hold)))

        clock.advance(by: 30)
        controller.tickNow()
        controller.mark()

        #expect(controller.isFinished)
        #expect(controller.summary?.measuredSeconds == 30)
        #expect(controller.summary?.isComplete == true)
        #expect(sink.ends == 1)
        #expect(sink.cues.contains(.speak("Recorded 30 s.")))
    }

    @Test func endingEarlyProducesAnAbortedSummary() {
        let clock = ManualClock()
        let sink = RecordingCueSink()
        let controller = SessionController(plan: .cadence(bolt: 25), clock: clock, cueSink: sink)
        controller.start()
        clock.advance(by: 25)
        controller.tickNow()
        #expect(controller.snapshot.round == 1)

        controller.end()
        #expect(controller.isFinished)
        #expect(controller.summary?.wasAborted == true)
        #expect((controller.summary?.completedSteps ?? 0) > 0)
        #expect(sink.ends == 1)
        #expect(sink.cues.last == .haptic(.warning))

        // Further calls are ignored once finished.
        controller.end()
        controller.mark()
        #expect(sink.ends == 1)
    }

    @Test func pauseFreezesTheClock() {
        let clock = ManualClock()
        let controller = SessionController(plan: .co2Table(maxHold: 90), clock: clock, cueSink: SilentCueSink())
        controller.start()
        clock.advance(by: 5)
        controller.tickNow()
        #expect(controller.snapshot.stepElapsed == 5)

        controller.togglePause()
        #expect(controller.state == .paused)
        clock.advance(by: 60)
        controller.tickNow()
        #expect(controller.snapshot.stepElapsed == 5)

        controller.togglePause()
        #expect(controller.state == .running)
        clock.advance(by: 5)
        controller.tickNow()
        #expect(controller.snapshot.phase == .recover)
        #expect(controller.snapshot.round == 1)
    }

    @Test func silentSchedulerProducesNoCues() {
        let sink = RecordingCueSink()
        let controller = SessionController(plan: .imt(), clock: ManualClock(), scheduler: .silent, cueSink: sink)
        controller.start()
        #expect(sink.cues.isEmpty)
        #expect(sink.starts == 1)
    }
}
