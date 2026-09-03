import BreatheKit
import Foundation
import SwiftData

@MainActor
enum PersistenceController {
    static let schema = Schema([UserProfile.self, AssessmentRecord.self, SessionRecord.self])

    static func makeContainer(inMemory: Bool) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the model container: \(error)")
        }
    }

    /// Applies launch flags (reset, skip onboarding, seeded baselines).
    static func applyLaunchConfiguration(_ launch: LaunchConfiguration, to context: ModelContext) {
        let store = ProfileStore(context: context)
        if launch.resetsState {
            try? store.reset()
        }
        guard launch.skipsOnboarding || launch.seedsBaselines else { return }
        guard let profile = try? store.profile() else { return }
        if launch.skipsOnboarding {
            profile.onboardingCompleted = true
            profile.safetyAcknowledgedAt = Date()
        }
        if launch.seedsBaselines {
            let now = Date()
            profile.apply(Baselines(boltSeconds: 28, maxHoldSeconds: 90, breathCountSeconds: 30, breathCount: 38, assessedAt: now))
            context.insert(AssessmentRecord(kind: .boltAssessment, seconds: 28, date: now))
            context.insert(AssessmentRecord(kind: .maxHoldAssessment, seconds: 90, date: now))
            context.insert(AssessmentRecord(kind: .breathCountAssessment, seconds: 30, count: 38, date: now))
        }
        try? context.save()
    }
}

/// All writes to the store go through here so views stay thin.
@MainActor
struct ProfileStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Fetches the profile, creating it on first launch.
    func profile() throws -> UserProfile {
        var descriptor = FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let profile = UserProfile()
        context.insert(profile)
        try context.save()
        return profile
    }

    func acknowledgeSafety(at date: Date = Date()) throws {
        let profile = try profile()
        profile.safetyAcknowledgedAt = date
        try context.save()
    }

    func completeOnboarding() throws {
        let profile = try profile()
        profile.onboardingCompleted = true
        try context.save()
    }

    /// Stores an assessment result and updates the baselines used for planning.
    @discardableResult
    func recordAssessment(kind: SessionKind, seconds: TimeInterval, count: Int? = nil, date: Date = Date()) throws -> AssessmentRecord {
        precondition(kind.isAssessment, "recordAssessment requires an assessment kind")
        let profile = try profile()
        var baselines = profile.baselines
        baselines.record(kind, seconds: seconds, count: count, at: date)
        profile.apply(baselines)
        let record = AssessmentRecord(kind: kind, seconds: seconds, count: count, date: date)
        context.insert(record)
        try context.save()
        return record
    }

    /// Stores a finished session. Assessment results are also recorded as baselines.
    @discardableResult
    func recordSession(_ summary: SessionSummary, startedAt: Date, breathCount: Int? = nil) throws -> SessionRecord {
        let profile = try profile()
        let record = SessionRecord(summary: summary, startedAt: startedAt)
        context.insert(record)
        if summary.isComplete {
            profile.completedSessionCount += 1
        }
        if summary.kind.isAssessment, let measured = summary.measuredSeconds {
            var baselines = profile.baselines
            baselines.record(summary.kind, seconds: measured, count: breathCount, at: startedAt)
            profile.apply(baselines)
            context.insert(AssessmentRecord(kind: summary.kind, seconds: measured, count: breathCount, date: startedAt))
        }
        try context.save()
        return record
    }

    func sessions() throws -> [SessionRecord] {
        try context.fetch(FetchDescriptor<SessionRecord>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))
    }

    func assessments(of kind: SessionKind) throws -> [AssessmentRecord] {
        let raw = kind.rawValue
        let descriptor = FetchDescriptor<AssessmentRecord>(
            predicate: #Predicate<AssessmentRecord> { $0.kindRaw == raw },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    /// Deletes everything. The next `profile()` call starts fresh.
    func reset() throws {
        try context.delete(model: SessionRecord.self)
        try context.delete(model: AssessmentRecord.self)
        try context.delete(model: UserProfile.self)
        try context.save()
    }
}
