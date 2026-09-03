import BreatheKit
import Foundation
import SwiftData
import Testing
@testable import BreatheApp

@MainActor
struct ProfileStoreTests {
    private func makeStore() -> ProfileStore {
        ProfileStore(context: PersistenceController.makeContainer(inMemory: true).mainContext)
    }

    @Test func profileIsCreatedOnceAndReused() throws {
        let store = makeStore()
        let first = try store.profile()
        let second = try store.profile()
        #expect(first.persistentModelID == second.persistentModelID)
        #expect(!first.onboardingCompleted)
        #expect(first.baselines == .empty)
    }

    @Test func recordingAnAssessmentUpdatesBaselinesAndHistory() throws {
        let store = makeStore()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        try store.recordAssessment(kind: .boltAssessment, seconds: 28, date: date)
        try store.recordAssessment(kind: .breathCountAssessment, seconds: 33, count: 40, date: date)

        let profile = try store.profile()
        #expect(profile.boltSeconds == 28)
        #expect(profile.breathCountSeconds == 33)
        #expect(profile.breathCount == 40)
        #expect(profile.assessedAt == date)
        #expect(profile.baselines.missingAssessments == [.maxHoldAssessment])
        #expect(try store.assessments(of: .boltAssessment).count == 1)
        #expect(try store.assessments(of: .maxHoldAssessment).isEmpty)
    }

    @Test func completedSessionsAreCountedAndAssessmentSessionsUpdateBaselines() throws {
        let store = makeStore()
        let plan = SessionPlan.maxHoldAssessment()
        let summary = SessionSummary(kind: .maxHoldAssessment, title: plan.title, totalElapsed: 100, plannedDuration: 35,
                                     completedSteps: plan.stepCount, stepCount: plan.stepCount,
                                     holdDurations: [65], measuredSeconds: 65, wasAborted: false)
        try store.recordSession(summary, startedAt: Date())
        let aborted = SessionSummary(kind: .cadence, title: "Cadence", totalElapsed: 30, plannedDuration: 210,
                                     completedSteps: 3, stepCount: 41, holdDurations: [6], measuredSeconds: nil, wasAborted: true)
        try store.recordSession(aborted, startedAt: Date())

        let profile = try store.profile()
        #expect(profile.completedSessionCount == 1)
        #expect(profile.maxHoldSeconds == 65)
        #expect(try store.sessions().count == 2)
        #expect(try store.assessments(of: .maxHoldAssessment).first?.seconds == 65)
    }

    @Test func resetClearsEverything() throws {
        let store = makeStore()
        try store.recordAssessment(kind: .boltAssessment, seconds: 20)
        try store.completeOnboarding()
        try store.reset()
        let profile = try store.profile()
        #expect(!profile.onboardingCompleted)
        #expect(profile.boltSeconds == nil)
        #expect(try store.sessions().isEmpty)
    }

    @Test func launchFlagsSeedTheStore() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let launch = LaunchConfiguration.parse(["-skipOnboarding", "-seedBaselines"])
        PersistenceController.applyLaunchConfiguration(launch, to: container.mainContext)
        let store = ProfileStore(context: container.mainContext)
        let profile = try store.profile()
        #expect(profile.onboardingCompleted)
        #expect(profile.boltSeconds == 28)
        #expect(profile.maxHoldSeconds == 90)
        #expect(try store.assessments(of: .breathCountAssessment).first?.count == 38)
    }
}
