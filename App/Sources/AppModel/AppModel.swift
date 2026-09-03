import BreatheKit
import Foundation
import Observation

/// App-wide state: launch configuration and the session in progress.
@Observable
@MainActor
final class AppModel {
    let launch: LaunchConfiguration
    var activeSession: SessionController?

    private var cuePlayer: CuePlayer?

    init(launch: LaunchConfiguration = .current) {
        self.launch = launch
    }

    /// Builds the standard plan for a kind and starts it.
    @discardableResult
    func startSession(kind: SessionKind, baselines: Baselines, scheduler: CueScheduler, rounds: Int? = nil) -> SessionController {
        startSession(plan: SessionPlan.standard(for: kind, baselines: baselines, rounds: rounds), scheduler: scheduler)
    }

    @discardableResult
    func startSession(plan: SessionPlan, scheduler: CueScheduler) -> SessionController {
        activeSession?.end()
        let controller = SessionController(
            plan: plan,
            clock: makeClock(),
            scheduler: scheduler,
            cueSink: makeCueSink(),
            pedometer: launch.isUITesting ? nil : PedometerService()
        )
        activeSession = controller
        controller.start()
        return controller
    }

    /// Ends any running session and closes the player.
    func dismissSession() {
        activeSession?.end()
        activeSession = nil
    }

    private func makeClock() -> any SessionClock {
        launch.timeScale == 1 ? ContinuousSessionClock() : ScaledSessionClock(scale: launch.timeScale)
    }

    private func makeCueSink() -> any CueSink {
        guard launch.isAudioEnabled else { return SilentCueSink() }
        if let cuePlayer { return cuePlayer }
        let player = CuePlayer()
        cuePlayer = player
        return player
    }
}
