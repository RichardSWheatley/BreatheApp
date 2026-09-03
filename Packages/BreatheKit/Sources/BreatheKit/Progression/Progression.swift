import Foundation

/// Rules that personalise and progress training over time.
public enum Progression {
    /// Max hold assumed for plan previews before the user has been assessed.
    public static let defaultMaxHold: TimeInterval = 60
    /// The PRD asks for bi-weekly BOLT re-tests.
    public static let reassessmentInterval: TimeInterval = 14 * 86_400

    /// Base hold in the 4-6-4-6 cadence.
    public static let baseCadenceHold: TimeInterval = 6
    /// Holds never scale past this, regardless of BOLT.
    public static let maxCadenceHold: TimeInterval = 15
    /// BOLT score at which scaling starts ("normal" per the PRD).
    public static let boltReference: TimeInterval = 25
    /// One extra second of hold for every this many BOLT seconds above the reference.
    public static let boltSecondsPerHoldSecond: TimeInterval = 3

    /// Cadence hold length for a BOLT score. `nil` (not yet assessed) gives the base hold.
    ///
    /// Examples: BOLT 20 → 6 s, BOLT 25 → 6 s, BOLT 31 → 8 s, BOLT 40 → 11 s, BOLT 52+ → 15 s.
    public static func cadenceHold(bolt: TimeInterval?) -> TimeInterval {
        guard let bolt, bolt > boltReference else { return baseCadenceHold }
        let extra = ((bolt - boltReference) / boltSecondsPerHoldSecond).rounded(.down)
        return min(baseCadenceHold + extra, maxCadenceHold)
    }

    public static func isReassessmentDue(lastAssessment: Date?, now: Date = Date()) -> Bool {
        guard let lastAssessment else { return true }
        return now.timeIntervalSince(lastAssessment) >= reassessmentInterval
    }

    public static func nextReassessment(after lastAssessment: Date) -> Date {
        lastAssessment.addingTimeInterval(reassessmentInterval)
    }

    /// Whole days until the next re-test; 0 when due.
    public static func daysUntilReassessment(lastAssessment: Date?, now: Date = Date()) -> Int {
        guard let lastAssessment else { return 0 }
        let remaining = nextReassessment(after: lastAssessment).timeIntervalSince(now)
        return max(0, Int((remaining / 86_400).rounded(.up)))
    }

    /// Weekly rotation through the four pillars. Cadence and IMT are the
    /// low-intensity anchors; tables and sprints are spaced out for recovery.
    public static let rotation: [SessionKind] = [
        .cadence, .co2Table, .imt, .hypoxicSprints, .cadence, .o2Table, .imt,
    ]

    /// What to do next: a missing assessment first, otherwise the rotation.
    public static func recommendedKind(baselines: Baselines, completedSessions: Int) -> SessionKind {
        if let missing = baselines.missingAssessments.first {
            return missing
        }
        let index = ((completedSessions % rotation.count) + rotation.count) % rotation.count
        return rotation[index]
    }

    /// Rough length shown on library cards. Open-ended assessments add a
    /// nominal minute for the hold itself.
    public static func estimatedDuration(for kind: SessionKind, baselines: Baselines) -> TimeInterval {
        let plan = SessionPlan.standard(for: kind, baselines: baselines)
        return plan.plannedDuration + (plan.isOpenEnded ? 60 : 0)
    }
}
