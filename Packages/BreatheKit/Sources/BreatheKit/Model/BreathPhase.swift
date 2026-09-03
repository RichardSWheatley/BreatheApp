import Foundation

/// The physiological state a session step asks the user to be in.
///
/// Every protocol in the app (tables, cadence breathing, hypoxic sprints,
/// inspiratory muscle training and the three baseline assessments) is
/// expressed as an ordered list of `SessionStep`s, each tagged with one of
/// these phases. The UI maps a phase to a colour, a pacer motion and a set
/// of audio/haptic cues; the engine only cares about durations.
public enum BreathPhase: String, Codable, Sendable, CaseIterable, Hashable {
    /// "Get ready" countdown before the first working step.
    case prepare
    /// Fill the lungs.
    case inhale
    /// Empty the lungs.
    case exhale
    /// Breath hold on full lungs (after an inhale).
    case holdFull
    /// Breath hold on empty lungs (after an exhale).
    case holdEmpty
    /// Relaxed, normal breathing between holds (tables, sprints).
    case recover
    /// Breath hold on empty lungs while walking a target number of paces.
    case walkHold
    /// Forceful inhale against manual resistance (pursed lips / straw).
    case resistedInhale
    /// Rest between sets of inspiratory muscle training.
    case rest
    /// Single continuous exhale while counting aloud (assessment).
    case countAloud
    /// Terminal state shown after the last step has finished.
    case complete

    /// Short, human readable label ("Inhale", "Hold", ...).
    public var displayName: String {
        switch self {
        case .prepare: return "Get Ready"
        case .inhale: return "Inhale"
        case .exhale: return "Exhale"
        case .holdFull: return "Hold"
        case .holdEmpty: return "Hold"
        case .recover: return "Breathe"
        case .walkHold: return "Walk & Hold"
        case .resistedInhale: return "Power Inhale"
        case .rest: return "Rest"
        case .countAloud: return "Count"
        case .complete: return "Complete"
        }
    }

    /// Whether the user is holding their breath during this phase.
    public var isHold: Bool {
        switch self {
        case .holdFull, .holdEmpty, .walkHold: return true
        default: return false
        }
    }

    /// Whether the user is breathing freely (no pacing target).
    public var isFreeBreathing: Bool {
        switch self {
        case .prepare, .recover, .rest, .complete: return true
        default: return false
        }
    }

    /// How full the lungs are expected to be at the *start* of the phase,
    /// on a 0 (empty) ... 1 (full) scale. Used by the pacer.
    public var startingFullness: Double {
        switch self {
        case .inhale, .resistedInhale: return 0
        case .exhale: return 1
        case .holdFull, .countAloud: return 1
        case .holdEmpty, .walkHold: return 0
        case .prepare, .recover, .rest, .complete: return 0.5
        }
    }
}
