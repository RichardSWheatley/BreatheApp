import BreatheKit
import Foundation
import SwiftData

/// The single user profile: onboarding state, baselines and preferences.
@Model
final class UserProfile {
    var createdAt: Date
    var onboardingCompleted: Bool
    var safetyAcknowledgedAt: Date?
    var boltSeconds: Double?
    var maxHoldSeconds: Double?
    var breathCountSeconds: Double?
    var breathCount: Int?
    var assessedAt: Date?
    var completedSessionCount: Int
    var voiceEnabled: Bool
    var tonesEnabled: Bool
    var hapticsEnabled: Bool

    init(createdAt: Date = Date()) {
        self.createdAt = createdAt
        onboardingCompleted = false
        safetyAcknowledgedAt = nil
        completedSessionCount = 0
        voiceEnabled = true
        tonesEnabled = true
        hapticsEnabled = true
    }

    var baselines: Baselines {
        Baselines(
            boltSeconds: boltSeconds,
            maxHoldSeconds: maxHoldSeconds,
            breathCountSeconds: breathCountSeconds,
            breathCount: breathCount,
            assessedAt: assessedAt
        )
    }

    func apply(_ baselines: Baselines) {
        boltSeconds = baselines.boltSeconds
        maxHoldSeconds = baselines.maxHoldSeconds
        breathCountSeconds = baselines.breathCountSeconds
        breathCount = baselines.breathCount
        assessedAt = baselines.assessedAt
    }

    var cueScheduler: CueScheduler {
        CueScheduler(voiceEnabled: voiceEnabled, tonesEnabled: tonesEnabled, hapticsEnabled: hapticsEnabled)
    }
}

/// One recorded assessment result.
@Model
final class AssessmentRecord {
    var kindRaw: String
    var seconds: Double
    var count: Int?
    var date: Date

    init(kind: SessionKind, seconds: Double, count: Int? = nil, date: Date = Date()) {
        kindRaw = kind.rawValue
        self.seconds = seconds
        self.count = count
        self.date = date
    }

    var kind: SessionKind? { SessionKind(rawValue: kindRaw) }

    var band: PerformanceBand? {
        kind.flatMap { AssessmentScoring.band(for: $0, seconds: seconds) }
    }
}

/// One completed or abandoned training session.
@Model
final class SessionRecord {
    var kindRaw: String
    var startedAt: Date
    var duration: Double
    var completed: Bool
    var holdSeconds: [Double]
    var measuredSeconds: Double?

    init(summary: SessionSummary, startedAt: Date) {
        kindRaw = summary.kind.rawValue
        self.startedAt = startedAt
        duration = summary.totalElapsed
        completed = summary.isComplete
        holdSeconds = summary.holdDurations
        measuredSeconds = summary.measuredSeconds
    }

    var kind: SessionKind? { SessionKind(rawValue: kindRaw) }
    var title: String { kind?.title ?? kindRaw }
    var longestHold: Double? { holdSeconds.max() }
}
