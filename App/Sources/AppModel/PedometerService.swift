import CoreMotion
import Foundation

/// Counts paces during walking breath holds so the hold can end when the
/// target is reached rather than purely on time. Falls back silently to
/// time-based holds where step counting is unavailable (Simulator, no
/// motion permission).
@MainActor
final class PedometerService {
    private let pedometer = CMPedometer()

    var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    func startCounting(onUpdate: @escaping @MainActor (Int) -> Void) {
        guard isAvailable else { return }
        pedometer.startUpdates(from: Date()) { data, error in
            guard error == nil, let steps = data?.numberOfSteps.intValue else { return }
            Task { @MainActor in
                onUpdate(steps)
            }
        }
    }

    func stop() {
        pedometer.stopUpdates()
    }
}
