import BreatheKit
import SwiftUI

/// The expanding / contracting circle. Scale follows lung fullness; with
/// Reduce Motion the circle stays put and its opacity breathes instead.
struct PacerCircle: View {
    let fullness: Double
    let phase: BreathPhase
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(PhaseStyle.color(for: phase).opacity(0.25), lineWidth: 2)
            Circle()
                .fill(PhaseStyle.gradient(for: phase))
                .scaleEffect(reduceMotion ? 0.85 : Pacer.scale(fullness: fullness))
                .opacity(reduceMotion ? 0.35 + 0.65 * fullness : 1)
                .shadow(color: PhaseStyle.color(for: phase).opacity(0.35), radius: 28)
        }
        .frame(width: 260, height: 260)
        .animation(.linear(duration: 0.1), value: fullness)
        .animation(.easeInOut(duration: 0.4), value: phase)
        .accessibilityHidden(true)
    }
}
