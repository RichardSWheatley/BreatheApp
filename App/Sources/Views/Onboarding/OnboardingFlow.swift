import BreatheKit
import SwiftUI

enum OnboardingPage: Hashable {
    case science(Int)
    case safety
    case assessment(SessionKind)
    case finish
}

struct OnboardingFlow: View {
    @Bindable var profile: UserProfile
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @State private var path: [OnboardingPage] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomePage {
                path.append(.science(0))
            }
            .navigationDestination(for: OnboardingPage.self) { page in
                destination(for: page)
            }
        }
    }

    @ViewBuilder
    private func destination(for page: OnboardingPage) -> some View {
        switch page {
        case .science(let index):
            SciencePage(topic: Education.mechanisms[index], index: index, total: Education.mechanisms.count) {
                if index + 1 < Education.mechanisms.count {
                    path.append(.science(index + 1))
                } else {
                    path.append(.safety)
                }
            }
        case .safety:
            SafetyPage {
                try? ProfileStore(context: context).acknowledgeSafety()
                path.append(.assessment(.boltAssessment))
            }
        case .assessment(let kind):
            AssessmentPage(kind: kind, profile: profile) {
                appModel.startSession(kind: kind, baselines: profile.baselines, scheduler: profile.cueScheduler)
            } next: {
                switch kind {
                case .boltAssessment: path.append(.assessment(.maxHoldAssessment))
                case .maxHoldAssessment: path.append(.assessment(.breathCountAssessment))
                default: path.append(.finish)
                }
            }
        case .finish:
            FinishPage(profile: profile) {
                try? ProfileStore(context: context).completeOnboarding()
            }
        }
    }
}

struct WelcomePage: View {
    let next: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lungs.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("Breathe")
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text("Train your VO2 max and breath-holding capacity with guided breathing protocols built on three proven mechanisms.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            VStack(alignment: .leading, spacing: 8) {
                Label("Athletes: higher VO2 max, later fatigue", systemImage: "figure.run")
                Label("Vocalists: CO2 tolerance, longer phrases", systemImage: "music.mic")
            }
            .font(.subheadline)
            Spacer()
            Button {
                next()
            } label: {
                Text("Get started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier(AccessibilityID.Onboarding.getStarted)
        }
        .padding()
    }
}

struct SciencePage: View {
    let topic: EducationTopic
    let index: Int
    let total: Int
    let next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("The science · \(index + 1) of \(total)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Image(systemName: topic.symbolName)
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text(topic.title)
                .font(.title.weight(.bold))
            Text(topic.summary)
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(topic.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                    }
                }
            }
            Button {
                next()
            } label: {
                Text(index + 1 < total ? "Next" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier(AccessibilityID.Onboarding.next)
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SafetyPage: View {
    let next: () -> Void
    @State private var acknowledged = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: Education.safety.symbolName)
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text(Education.safety.title)
                .font(.title.weight(.bold))
            Text(Education.safety.paragraphs.joined(separator: " "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Education.safetyRules, id: \.self) { rule in
                        Label(rule, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                    }
                }
            }
            Toggle("I understand these rules and will follow them.", isOn: $acknowledged)
                .font(.headline)
                .accessibilityIdentifier(AccessibilityID.Onboarding.safetyAcknowledge)
            Button {
                next()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!acknowledged)
            .accessibilityIdentifier(AccessibilityID.Onboarding.safetyContinue)
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AssessmentPage: View {
    let kind: SessionKind
    @Bindable var profile: UserProfile
    let start: () -> Void
    let next: () -> Void

    private var result: TimeInterval? {
        switch kind {
        case .boltAssessment: return profile.boltSeconds
        case .maxHoldAssessment: return profile.maxHoldSeconds
        case .breathCountAssessment: return profile.breathCountSeconds
        default: return nil
        }
    }

    private var guide: EducationTopic { Education.guide(for: kind) }

    private var position: Int {
        (SessionKind.assessments.firstIndex(of: kind) ?? 0) + 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Baseline \(position) of \(SessionKind.assessments.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Image(systemName: kind.symbolName)
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text(kind.title)
                .font(.title.weight(.bold))
            Text(kind.goal)
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(guide.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                    }
                }
            }
            if let result {
                HStack(spacing: 14) {
                    Text(TimeFormatting.compact(result))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    if let band = AssessmentScoring.band(for: kind, seconds: result) {
                        BandBadge(band: band)
                    }
                    Spacer()
                    Button("Redo") { start() }
                        .buttonStyle(.bordered)
                }
                .padding()
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Button {
                    next()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier(AccessibilityID.Onboarding.resultContinue)
            } else {
                Button {
                    start()
                } label: {
                    Label("Start \(kind.shortTitle) test", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier(AccessibilityID.Onboarding.assessmentStart)
            }
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FinishPage: View {
    @Bindable var profile: UserProfile
    let finish: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Baselines set")
                .font(.title.weight(.bold))
            Text("Every plan is now scaled to you. Re-test your BOLT every two weeks and your holds grow with it.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                BaselineTile(kind: .boltAssessment, seconds: profile.boltSeconds)
                BaselineTile(kind: .maxHoldAssessment, seconds: profile.maxHoldSeconds)
                BaselineTile(kind: .breathCountAssessment, seconds: profile.breathCountSeconds)
            }
            Spacer()
            Button {
                finish()
            } label: {
                Text("Start training")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier(AccessibilityID.Onboarding.finish)
        }
        .padding()
        .navigationBarBackButtonHidden()
    }
}
