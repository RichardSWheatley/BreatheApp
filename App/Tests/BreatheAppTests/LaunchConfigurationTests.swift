import Testing
@testable import BreatheApp

struct LaunchConfigurationTests {
    @Test func defaultsAreRealTimeAndPersistent() {
        let configuration = LaunchConfiguration.parse(["BreatheApp"])
        #expect(configuration == LaunchConfiguration())
        #expect(configuration.timeScale == 1)
        #expect(configuration.isAudioEnabled)
    }

    @Test func uiTestingImpliesInMemoryResetAndMutedAudio() {
        let configuration = LaunchConfiguration.parse(["BreatheApp", "-uiTesting", "-timeScale", "40"])
        #expect(configuration.isUITesting)
        #expect(configuration.usesInMemoryStore)
        #expect(configuration.resetsState)
        #expect(configuration.timeScale == 40)
        #expect(!configuration.isAudioEnabled)
    }

    @Test func individualFlags() {
        let configuration = LaunchConfiguration.parse(["-skipOnboarding", "-seedBaselines", "-inMemoryStore"])
        #expect(configuration.skipsOnboarding)
        #expect(configuration.seedsBaselines)
        #expect(configuration.usesInMemoryStore)
        #expect(!configuration.resetsState)
    }

    @Test(arguments: [["-timeScale"], ["-timeScale", "abc"], ["-timeScale", "0"], ["-timeScale", "-5"]])
    func invalidTimeScaleIsIgnored(arguments: [String]) {
        #expect(LaunchConfiguration.parse(arguments).timeScale == 1)
    }
}
