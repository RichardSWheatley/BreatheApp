import Foundation

/// Launch arguments used by UI tests and local debugging.
///
///   -uiTesting          in-memory store, fresh state, audio muted
///   -inMemoryStore      do not persist anything to disk
///   -resetState         wipe stored data at launch
///   -skipOnboarding     mark onboarding as complete
///   -seedBaselines      store BOLT 28 s / max hold 90 s / count 30 s
///   -timeScale <x>      run sessions x times faster than real time
struct LaunchConfiguration: Equatable, Sendable {
    var isUITesting = false
    var usesInMemoryStore = false
    var resetsState = false
    var skipsOnboarding = false
    var seedsBaselines = false
    var timeScale: Double = 1

    static var current: LaunchConfiguration {
        parse(ProcessInfo.processInfo.arguments)
    }

    static func parse(_ arguments: [String]) -> LaunchConfiguration {
        var configuration = LaunchConfiguration()
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "-uiTesting":
                configuration.isUITesting = true
                configuration.usesInMemoryStore = true
                configuration.resetsState = true
            case "-inMemoryStore":
                configuration.usesInMemoryStore = true
            case "-resetState":
                configuration.resetsState = true
            case "-skipOnboarding":
                configuration.skipsOnboarding = true
            case "-seedBaselines":
                configuration.seedsBaselines = true
            case "-timeScale":
                if let raw = iterator.next(), let scale = Double(raw), scale > 0 {
                    configuration.timeScale = scale
                }
            default:
                continue
            }
        }
        return configuration
    }

    /// Audio and speech are silenced during UI tests to keep runs fast and quiet.
    var isAudioEnabled: Bool { !isUITesting }
}
