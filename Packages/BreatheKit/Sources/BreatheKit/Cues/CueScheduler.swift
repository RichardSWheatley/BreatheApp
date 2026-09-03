import Foundation

/// Decides which cues fire for each engine event.
///
/// This is a pure mapping so the eyes-free guidance can be unit tested:
/// give it an event, get back the exact list of tones, haptics and spoken
/// prompts. Users can switch each channel off independently.
public struct CueScheduler: Sendable, Hashable {
    public var voiceEnabled: Bool
    public var tonesEnabled: Bool
    public var hapticsEnabled: Bool
    /// Speak "3, 2, 1" in the run-up to a breath hold.
    public var speaksCountdownBeforeHolds: Bool

    public init(
        voiceEnabled: Bool = true,
        tonesEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        speaksCountdownBeforeHolds: Bool = true
    ) {
        self.voiceEnabled = voiceEnabled
        self.tonesEnabled = tonesEnabled
        self.hapticsEnabled = hapticsEnabled
        self.speaksCountdownBeforeHolds = speaksCountdownBeforeHolds
    }

    public static let standard = CueScheduler()
    public static let silent = CueScheduler(voiceEnabled: false, tonesEnabled: false, hapticsEnabled: false)

    /// Cues for an event, filtered by the enabled channels.
    public func cues(for event: SessionEvent) -> [Cue] {
        unfilteredCues(for: event).filter { cue in
            switch cue {
            case .tone: return tonesEnabled
            case .haptic: return hapticsEnabled
            case .speak: return voiceEnabled
            }
        }
    }

    /// The full cue list before channel filtering.
    public func unfilteredCues(for event: SessionEvent) -> [Cue] {
        switch event {
        case .started:
            return []

        case .stepBegan(_, let step):
            var cues: [Cue] = []
            if let tone = Self.tone(for: step.phase) {
                cues.append(.tone(tone))
            }
            cues.append(.haptic(Self.haptic(for: step.phase)))
            cues.append(.speak(step.voicePrompt))
            return cues

        case .stepEnded(_, let step, let elapsed, _):
            guard step.isMeasured else { return [] }
            return [.tone(.chime), .haptic(.success), .speak("Recorded \(TimeFormatting.spoken(elapsed)).")]

        case .countdown(let secondsRemaining, _, let nextStep):
            var cues: [Cue] = [.tone(.tick), .haptic(.tick)]
            if speaksCountdownBeforeHolds, let nextStep, nextStep.phase.isHold {
                cues.append(.speak("\(secondsRemaining)"))
            }
            return cues

        case .paused:
            return [.haptic(.light), .speak("Paused")]

        case .resumed:
            return [.haptic(.light), .speak("Resuming")]

        case .completed(let summary):
            return [.tone(.chime), .haptic(.success), .speak(Self.completionPhrase(for: summary))]

        case .aborted:
            return [.haptic(.warning)]
        }
    }

    public static func tone(for phase: BreathPhase) -> Tone? {
        switch phase {
        case .inhale, .resistedInhale: return .inhale
        case .exhale: return .exhale
        case .holdFull, .holdEmpty, .walkHold, .countAloud: return .hold
        case .recover, .rest: return .release
        case .prepare, .complete: return nil
        }
    }

    public static func haptic(for phase: BreathPhase) -> HapticPattern {
        switch phase {
        case .holdFull, .holdEmpty, .walkHold: return .heavy
        case .inhale, .exhale, .resistedInhale, .countAloud: return .medium
        case .prepare, .recover, .rest, .complete: return .light
        }
    }

    public static func completionPhrase(for summary: SessionSummary) -> String {
        if let measured = summary.measuredSeconds {
            return "Assessment complete. \(TimeFormatting.spoken(measured))."
        }
        return "Session complete. \(TimeFormatting.spoken(summary.totalElapsed)) of training. Well done."
    }
}
