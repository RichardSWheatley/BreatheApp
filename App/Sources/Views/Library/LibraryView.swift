import BreatheKit
import SwiftUI

struct LibraryView: View {
    @Bindable var profile: UserProfile

    var body: some View {
        NavigationStack {
            List {
                Section("Training") {
                    ForEach(SessionKind.trainingProtocols) { kind in
                        NavigationLink(value: kind) {
                            ProtocolRow(kind: kind, baselines: profile.baselines)
                        }
                        .accessibilityIdentifier(AccessibilityID.Library.card(kind.rawValue))
                    }
                }
                Section("Re-test baselines") {
                    ForEach(SessionKind.assessments) { kind in
                        NavigationLink(value: kind) {
                            ProtocolRow(kind: kind, baselines: profile.baselines)
                        }
                        .accessibilityIdentifier(AccessibilityID.Library.card(kind.rawValue))
                    }
                }
            }
            .navigationTitle("Train")
            .navigationDestination(for: SessionKind.self) { kind in
                ProtocolDetailView(kind: kind, profile: profile)
            }
        }
    }
}

struct ProtocolRow: View {
    let kind: SessionKind
    let baselines: Baselines

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: kind.symbolName)
                .font(.title2)
                .frame(width: 36)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title)
                    .font(.headline)
                Text(kind.goal)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\(kind.audience) · about \(TimeFormatting.clock(Progression.estimatedDuration(for: kind, baselines: baselines)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProtocolDetailView: View {
    let kind: SessionKind
    @Bindable var profile: UserProfile
    @Environment(AppModel.self) private var appModel
    @State private var rounds: Int

    init(kind: SessionKind, profile: UserProfile) {
        self.kind = kind
        _profile = Bindable(wrappedValue: profile)
        _rounds = State(initialValue: SessionPlan.defaultRounds(for: kind) ?? 1)
    }

    private var roundRange: ClosedRange<Int>? { SessionPlan.roundRange(for: kind) }

    private var plan: SessionPlan {
        SessionPlan.standard(for: kind, baselines: profile.baselines, rounds: roundRange == nil ? nil : rounds)
    }

    private var guide: EducationTopic { Education.guide(for: kind) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: kind.symbolName)
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading) {
                        Text(kind.audience)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(kind.goal)
                            .font(.subheadline)
                    }
                }

                ForEach(Array(guide.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(.body)
                }

                if let roundRange {
                    Stepper("\(roundLabel): \(rounds)", value: $rounds, in: roundRange)
                        .font(.headline)
                }

                GroupBox("Your plan") {
                    PlanOutlineView(plan: plan)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !profile.baselines.isComplete, !kind.isAssessment {
                    Label("Complete your baselines for a plan scaled to you. Until then a 60 s max hold is assumed.",
                          systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    appModel.startSession(plan: plan, scheduler: profile.cueScheduler)
                } label: {
                    Label("Start \(kind.shortTitle)", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier(AccessibilityID.Library.start)
            }
            .padding()
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var roundLabel: String {
        switch kind {
        case .hypoxicSprints: return "Reps"
        case .imt: return "Sets"
        default: return "Rounds"
        }
    }
}
