import Foundation

/// A monotonic time source the engine reads on every tick.
///
/// Injecting the clock keeps the engine deterministic: tests and the
/// simulator use `ManualClock`, the app uses `ContinuousSessionClock`, and UI
/// tests wrap it in `ScaledSessionClock` to fast-forward sessions.
public protocol SessionClock: Sendable {
    /// Seconds since an arbitrary fixed origin. Must never go backwards.
    var now: TimeInterval { get }
}

/// Wall time that keeps advancing while the device sleeps (`ContinuousClock`).
public struct ContinuousSessionClock: SessionClock {
    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant

    public init() {
        origin = clock.now
    }

    public var now: TimeInterval {
        origin.duration(to: clock.now).timeInterval
    }
}

/// A clock that only moves when told to. Thread-safe so it can be shared
/// with the engine from any context.
public final class ManualClock: SessionClock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: TimeInterval

    public init(now: TimeInterval = 0) {
        current = now
    }

    public var now: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    public func advance(by delta: TimeInterval) {
        precondition(delta >= 0, "ManualClock cannot move backwards")
        lock.lock()
        current += delta
        lock.unlock()
    }

    public func set(_ now: TimeInterval) {
        lock.lock()
        precondition(now >= current, "ManualClock cannot move backwards")
        current = now
        lock.unlock()
    }
}

/// Runs another clock faster (or slower) than real time.
public struct ScaledSessionClock: SessionClock {
    private let base: any SessionClock
    private let origin: TimeInterval
    public let scale: Double

    public init(base: any SessionClock = ContinuousSessionClock(), scale: Double) {
        precondition(scale > 0, "scale must be positive")
        self.base = base
        self.scale = scale
        origin = base.now
    }

    public var now: TimeInterval {
        (base.now - origin) * scale
    }
}

extension Duration {
    /// Seconds as a floating point value.
    public var timeInterval: TimeInterval {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
