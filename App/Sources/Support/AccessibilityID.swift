import Foundation

/// Accessibility identifiers shared between the app and its UI tests.
enum AccessibilityID {
    enum Onboarding {
        static let getStarted = "onboarding.getStarted"
        static let next = "onboarding.next"
        static let safetyAcknowledge = "onboarding.safety.acknowledge"
        static let safetyContinue = "onboarding.safety.continue"
        static let assessmentStart = "onboarding.assessment.start"
        static let resultContinue = "onboarding.result.continue"
        static let breathCountField = "onboarding.result.breathCount"
        static let finish = "onboarding.finish"
    }

    enum Tabs {
        static let today = "tab.today"
        static let train = "tab.train"
        static let progress = "tab.progress"
        static let learn = "tab.learn"
    }

    enum Home {
        static let startRecommended = "home.startRecommended"
        static let settings = "home.settings"
    }

    enum Library {
        static func card(_ kind: String) -> String { "library.card.\(kind)" }
        static let start = "library.start"
    }

    enum Session {
        static let phase = "session.phase"
        static let instruction = "session.instruction"
        static let timer = "session.timer"
        static let round = "session.round"
        static let mark = "session.mark"
        static let pause = "session.pause"
        static let end = "session.end"
        static let confirmEnd = "session.confirmEnd"
        static let summaryTitle = "session.summary.title"
        static let summaryDone = "session.summary.done"
        static let resultValue = "session.result.value"
    }
}
