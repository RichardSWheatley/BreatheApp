import BreatheKit
import SwiftUI

/// Visual identity of each breath phase.
enum PhaseStyle {
    static func color(for phase: BreathPhase) -> Color {
        switch phase {
        case .prepare: return .mint
        case .inhale: return .cyan
        case .exhale: return .indigo
        case .holdFull: return .orange
        case .holdEmpty: return .purple
        case .recover: return .green
        case .walkHold: return .red
        case .resistedInhale: return .pink
        case .rest: return .teal
        case .countAloud: return .yellow
        case .complete: return .green
        }
    }

    static func gradient(for phase: BreathPhase) -> LinearGradient {
        let base = color(for: phase)
        return LinearGradient(
            colors: [base.opacity(0.95), base.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func color(for band: PerformanceBand) -> Color {
        switch band {
        case .developing: return .orange
        case .normal: return .blue
        case .strong: return .green
        case .elite: return .purple
        }
    }
}
