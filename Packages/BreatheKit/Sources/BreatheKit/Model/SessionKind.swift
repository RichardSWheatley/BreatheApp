import Foundation

/// Which training protocol or baseline assessment a session runs.
public enum SessionKind: String, Codable, Sendable, CaseIterable, Identifiable, Hashable {
    // MARK: Training protocols (PRD §4)
    /// A. CO2 Tolerance Builder – paced 4-6-4-6 cadence breathing.
    case cadence
    /// B. Hypoxic Sprints – exhale, pinch nose, walk N paces, recover.
    case hypoxicSprints
    /// C. Apnea CO2 table – constant hold, shrinking recovery.
    case co2Table
    /// C. Apnea O2 table – constant recovery, growing hold.
    case o2Table
    /// D. Inspiratory Muscle Training – sets of forceful resisted inhales.
    case imt

    // MARK: Baseline assessments (PRD §3)
    /// Body Oxygen Level Test – CO2 tolerance.
    case boltAssessment
    /// Maximum static apnea – hypoxic tolerance.
    case maxHoldAssessment
    /// Single breath count – vocal breath control.
    case breathCountAssessment

    public var id: String { rawValue }

    public var isAssessment: Bool {
        switch self {
        case .boltAssessment, .maxHoldAssessment, .breathCountAssessment: return true
        default: return false
        }
    }

    public static var trainingProtocols: [SessionKind] {
        [.cadence, .hypoxicSprints, .co2Table, .o2Table, .imt]
    }

    public static var assessments: [SessionKind] {
        [.boltAssessment, .maxHoldAssessment, .breathCountAssessment]
    }

    public var title: String {
        switch self {
        case .cadence: return "CO2 Tolerance Builder"
        case .hypoxicSprints: return "Hypoxic Sprints"
        case .co2Table: return "CO2 Table"
        case .o2Table: return "O2 Table"
        case .imt: return "Inspiratory Muscle Training"
        case .boltAssessment: return "BOLT Score"
        case .maxHoldAssessment: return "Max Breath Hold"
        case .breathCountAssessment: return "Single Breath Count"
        }
    }

    public var shortTitle: String {
        switch self {
        case .cadence: return "Cadence"
        case .hypoxicSprints: return "Sprints"
        case .co2Table: return "CO2 Table"
        case .o2Table: return "O2 Table"
        case .imt: return "IMT"
        case .boltAssessment: return "BOLT"
        case .maxHoldAssessment: return "Max Hold"
        case .breathCountAssessment: return "Breath Count"
        }
    }

    /// The physiological goal, taken from the PRD.
    public var goal: String {
        switch self {
        case .cadence:
            return "Desensitise your chemoreceptors to CO2 build-up with paced breathing and holds."
        case .hypoxicSprints:
            return "Trigger spleen contraction and EPO release to expand VO2 max."
        case .co2Table:
            return "Raise CO2 tolerance: the hold stays fixed while recovery shrinks every round."
        case .o2Table:
            return "Push absolute breath-hold limits: recovery stays fixed while each hold grows."
        case .imt:
            return "Build diaphragm strength with forceful inhales against resistance."
        case .boltAssessment:
            return "Measures CO2 tolerance. Normal is around 25 s; elite is 40 s and above."
        case .maxHoldAssessment:
            return "Measures hypoxic tolerance: your longest comfortable static breath hold."
        case .breathCountAssessment:
            return "Measures vocal breath control: how long one steady exhale lasts."
        }
    }

    /// Which audience the protocol primarily serves.
    public var audience: String {
        switch self {
        case .cadence: return "Athletes & vocalists"
        case .hypoxicSprints: return "Athletes"
        case .co2Table, .o2Table: return "Vocalists & aquatic athletes"
        case .imt: return "Athletes & vocalists"
        case .boltAssessment, .maxHoldAssessment, .breathCountAssessment: return "Everyone"
        }
    }

    /// Name of the SF Symbol the UI uses for this kind.
    public var symbolName: String {
        switch self {
        case .cadence: return "circle.dotted.circle"
        case .hypoxicSprints: return "figure.walk"
        case .co2Table: return "tablecells"
        case .o2Table: return "tablecells.badge.ellipsis"
        case .imt: return "lungs.fill"
        case .boltAssessment: return "timer"
        case .maxHoldAssessment: return "stopwatch"
        case .breathCountAssessment: return "waveform"
        }
    }
}
