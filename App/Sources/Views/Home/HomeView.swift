import BreatheKit
import SwiftUI

struct HomeView: View {
    @Bindable var profile: UserProfile
    @Environment(AppModel.self) private var appModel
    @State private var showSettings = false

    private var baselines: Baselines { profile.baselines }

    private var recommended: SessionKind {
        Progression.recommendedKind(baselines: baselines, completedSessions: profile.completedSessionCount)
    }

    private var reassessmentDue: Bool {
        baselines.isComplete && Progression.isReassessmentDue(lastAssessment: profile.assessedAt)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    todayCard
                    if reassessmentDue {
                        reassessmentBanner
                    }
                    baselinesSection
                    tipCard
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier(AccessibilityID.Home.settings)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(profile: profile)
            }
        }
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(baselines.isComplete ? "Today's session" : "Next step", systemImage: recommended.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(recommended.title)
                .font(.title2.weight(.bold))
            Text(recommended.goal)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text("About \(TimeFormatting.clock(Progression.estimatedDuration(for: recommended, baselines: baselines)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    appModel.startSession(kind: recommended, baselines: baselines, scheduler: profile.cueScheduler)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(AccessibilityID.Home.startRecommended)
            }
        }
        .padding()
        .background(PhaseStyle.color(for: .inhale).opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var reassessmentBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("BOLT re-test due")
                    .font(.headline)
                Text("Two weeks since your last test. Your holds scale with this number.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Test") {
                appModel.startSession(kind: .boltAssessment, baselines: baselines, scheduler: profile.cueScheduler)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var baselinesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Baselines")
                    .font(.headline)
                Spacer()
                if let assessedAt = profile.assessedAt {
                    Text("Re-test in \(Progression.daysUntilReassessment(lastAssessment: assessedAt)) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 10) {
                BaselineTile(kind: .boltAssessment, seconds: baselines.boltSeconds)
                BaselineTile(kind: .maxHoldAssessment, seconds: baselines.maxHoldSeconds)
                BaselineTile(kind: .breathCountAssessment, seconds: baselines.breathCountSeconds)
            }
        }
    }

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Today's tip", systemImage: "lightbulb.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(Education.tip(for: Date()))
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SettingsView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Guidance") {
                    Toggle("Voice prompts", isOn: $profile.voiceEnabled)
                    Toggle("Tones", isOn: $profile.tonesEnabled)
                    Toggle("Haptics", isOn: $profile.hapticsEnabled)
                }
                Section {
                    NavigationLink("Safety rules") {
                        SafetyRulesView()
                    }
                }
                Section("Data") {
                    Button("Reset all data", role: .destructive) {
                        confirmReset = true
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete all baselines and history?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    try? ProfileStore(context: context).reset()
                    dismiss()
                }
            }
        }
    }
}

struct SafetyRulesView: View {
    var body: some View {
        List {
            Section {
                ForEach(Education.safety.paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                }
            }
            Section("Rules") {
                ForEach(Education.safetyRules, id: \.self) { rule in
                    Label(rule, systemImage: "exclamationmark.triangle")
                }
            }
        }
        .navigationTitle(Education.safety.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
