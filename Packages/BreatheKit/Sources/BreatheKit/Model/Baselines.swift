import Foundation

/// The user's most recent baseline assessment results (PRD §3).
///
/// These drive the personalised difficulty of every generated plan.
public struct Baselines: Codable, Sendable, Hashable {
    /// Body Oxygen Level Test, seconds until the first urge to breathe.
    public var boltSeconds: TimeInterval?
    /// Longest static breath hold on full lungs, seconds.
    public var maxHoldSeconds: TimeInterval?
    /// Length of one continuous counted exhale, seconds.
    public var breathCountSeconds: TimeInterval?
    /// The number the user reached during the single breath count.
    public var breathCount: Int?
    /// When the most recent assessment of any kind was recorded.
    public var assessedAt: Date?

    public init(
        boltSeconds: TimeInterval? = nil,
        maxHoldSeconds: TimeInterval? = nil,
        breathCountSeconds: TimeInterval? = nil,
        breathCount: Int? = nil,
        assessedAt: Date? = nil
    ) {
        self.boltSeconds = boltSeconds
        self.maxHoldSeconds = maxHoldSeconds
        self.breathCountSeconds = breathCountSeconds
        self.breathCount = breathCount
        self.assessedAt = assessedAt
    }

    public static let empty = Baselines()

    /// All three assessments have been completed at least once.
    public var isComplete: Bool {
        boltSeconds != nil && maxHoldSeconds != nil && breathCountSeconds != nil
    }

    /// The assessments still missing, in the order the onboarding runs them.
    public var missingAssessments: [SessionKind] {
        var missing: [SessionKind] = []
        if boltSeconds == nil { missing.append(.boltAssessment) }
        if maxHoldSeconds == nil { missing.append(.maxHoldAssessment) }
        if breathCountSeconds == nil { missing.append(.breathCountAssessment) }
        return missing
    }

    /// Records the result of an assessment session.
    public mutating func record(_ kind: SessionKind, seconds: TimeInterval, count: Int? = nil, at date: Date) {
        switch kind {
        case .boltAssessment: boltSeconds = seconds
        case .maxHoldAssessment: maxHoldSeconds = seconds
        case .breathCountAssessment:
            breathCountSeconds = seconds
            if let count { breathCount = count }
        default: return
        }
        assessedAt = date
    }
}

/// Qualitative bands for assessment results, used for feedback copy.
public enum PerformanceBand: String, Codable, Sendable, CaseIterable {
    case developing
    case normal
    case strong
    case elite

    public var displayName: String {
        switch self {
        case .developing: return "Developing"
        case .normal: return "Normal"
        case .strong: return "Strong"
        case .elite: return "Elite"
        }
    }
}

/// Maps raw assessment results to bands.
///
/// BOLT thresholds follow the PRD ("Normal ~25 s; Elite 40 s+"). The other
/// two use common freediving / vocal coaching rules of thumb and are easy
/// to tune in one place.
public enum AssessmentScoring {
    public static func boltBand(seconds: TimeInterval) -> PerformanceBand {
        switch seconds {
        case ..<15: return .developing
        case ..<30: return .normal
        case ..<40: return .strong
        default: return .elite
        }
    }

    public static func maxHoldBand(seconds: TimeInterval) -> PerformanceBand {
        switch seconds {
        case ..<45: return .developing
        case ..<90: return .normal
        case ..<150: return .strong
        default: return .elite
        }
    }

    public static func breathCountBand(seconds: TimeInterval) -> PerformanceBand {
        switch seconds {
        case ..<15: return .developing
        case ..<30: return .normal
        case ..<45: return .strong
        default: return .elite
        }
    }

    public static func band(for kind: SessionKind, seconds: TimeInterval) -> PerformanceBand? {
        switch kind {
        case .boltAssessment: return boltBand(seconds: seconds)
        case .maxHoldAssessment: return maxHoldBand(seconds: seconds)
        case .breathCountAssessment: return breathCountBand(seconds: seconds)
        default: return nil
        }
    }
}
