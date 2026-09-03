import Foundation

/// Short synthesised sounds. The app maps each to a frequency sweep.
public enum Tone: String, Sendable, Codable, CaseIterable, Hashable {
    /// Rising two-note figure: start filling the lungs.
    case inhale
    /// Falling two-note figure: start emptying the lungs.
    case exhale
    /// Single sustained note: begin a hold.
    case hold
    /// Soft low note: release / breathe freely.
    case release
    /// Short click for countdowns.
    case tick
    /// Bright chime for completions and recorded results.
    case chime
    /// Attention sound for warnings.
    case alert
}

/// Haptic feedback classes, mapped to UIKit feedback generators in the app.
public enum HapticPattern: String, Sendable, Codable, CaseIterable, Hashable {
    case light
    case medium
    case heavy
    case tick
    case success
    case warning
}

/// One thing the app should do to guide the user without them looking at
/// the screen.
public enum Cue: Sendable, Hashable {
    case tone(Tone)
    case haptic(HapticPattern)
    case speak(String)

    public var isSpeech: Bool {
        if case .speak = self { return true }
        return false
    }

    public var isTone: Bool {
        if case .tone = self { return true }
        return false
    }

    public var isHaptic: Bool {
        if case .haptic = self { return true }
        return false
    }
}
