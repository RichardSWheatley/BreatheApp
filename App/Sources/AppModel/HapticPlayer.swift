import BreatheKit
import UIKit

/// Maps `HapticPattern` onto the system feedback generators.
@MainActor
final class HapticPlayer {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    func prepare() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        selection.prepare()
        notification.prepare()
    }

    func play(_ pattern: HapticPattern) {
        switch pattern {
        case .light: light.impactOccurred()
        case .medium: medium.impactOccurred()
        case .heavy: heavy.impactOccurred(intensity: 1.0)
        case .tick: selection.selectionChanged()
        case .success: notification.notificationOccurred(.success)
        case .warning: notification.notificationOccurred(.warning)
        }
    }
}
