import BreatheKit
import SwiftUI

struct SessionPlayerView: View {
    let controller: SessionController
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmEnd = false

    var body: some View {
        ZStack {
            PhaseStyle.color(for: controller.snapshot.phase)
                .opacity(0.14)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: controller.snapshot.phase)
            if let summary = controller.summary {
                SessionSummaryView(summary: summary, startedAt: controller.startedAt ?? Date())
            } else {
                player
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var player: some View {
        let snapshot = controller.snapshot
        return VStack(spacing: 20) {
            header(snapshot)
            Spacer(minLength: 8)
            PacerCircle(fullness: snapshot.fullness, phase: snapshot.phase, reduceMotion: reduceMotion)
            Text(snapshot.phase.displayName)
                .font(.largeTitle.weight(.bold))
                .contentTransition(.opacity)
                .accessibilityIdentifier(AccessibilityID.Session.phase)
            Text(snapshot.step?.instruction ?? "")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
                .padding(.horizontal)
                .accessibilityIdentifier(AccessibilityID.Session.instruction)
            Text(timerText(snapshot))
                .font(.system(size: 56, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityIdentifier(AccessibilityID.Session.timer)
                .accessibilityLabel(snapshot.isOpenEnded ? "Elapsed \(timerText(snapshot))" : "Remaining \(timerText(snapshot))")
            chips(snapshot)
            Spacer(minLength: 8)
            ProgressView(value: snapshot.sessionProgress)
                .tint(PhaseStyle.color(for: snapshot.phase))
            controls(snapshot)
        }
        .padding()
        .confirmationDialog("End this session?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End session", role: .destructive) {
                controller.end()
            }
            .accessibilityIdentifier(AccessibilityID.Session.confirmEnd)
        }
    }

    private func header(_ snapshot: SessionSnapshot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.title)
                    .font(.headline)
                if snapshot.roundCount > 0 {
                    Text("\(roundLabel(snapshot.kind)) \(snapshot.round) of \(snapshot.roundCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(AccessibilityID.Session.round)
                }
            }
            Spacer()
            Button {
                confirmEnd = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("End session")
            .accessibilityIdentifier(AccessibilityID.Session.end)
        }
    }

    @ViewBuilder
    private func chips(_ snapshot: SessionSnapshot) -> some View {
        HStack(spacing: 12) {
            if let paces = snapshot.step?.paces {
                Label(controller.walkPaces > 0 ? "\(controller.walkPaces) / \(paces) paces" : "\(paces) paces", systemImage: "figure.walk")
            }
            if let rep = snapshot.step?.rep, let repCount = snapshot.step?.repCount {
                Label("Rep \(rep) of \(repCount)", systemImage: "repeat")
            }
            if let next = snapshot.nextStep, let remaining = snapshot.stepRemaining, remaining <= 3 {
                Label("Next: \(next.phase.displayName)", systemImage: "arrow.right")
            }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(minHeight: 24)
    }

    private func controls(_ snapshot: SessionSnapshot) -> some View {
        HStack(spacing: 16) {
            Button {
                controller.togglePause()
            } label: {
                Label(snapshot.state == .paused ? "Resume" : "Pause",
                      systemImage: snapshot.state == .paused ? "play.fill" : "pause.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier(AccessibilityID.Session.pause)

            Button {
                controller.mark()
            } label: {
                Label(snapshot.isOpenEnded ? "Stop" : "Skip",
                      systemImage: snapshot.isOpenEnded ? "stop.fill" : "forward.end.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(snapshot.isOpenEnded ? Color.red : Color.accentColor)
            .disabled(snapshot.state != .running)
            .accessibilityIdentifier(AccessibilityID.Session.mark)
        }
    }

    private func timerText(_ snapshot: SessionSnapshot) -> String {
        if let remaining = snapshot.stepRemaining {
            return TimeFormatting.clock(remaining)
        }
        return TimeFormatting.clock(snapshot.stepElapsed.rounded(.down))
    }

    private func roundLabel(_ kind: SessionKind) -> String {
        switch kind {
        case .hypoxicSprints: return "Rep"
        case .imt: return "Set"
        case .maxHoldAssessment: return "Breath"
        default: return "Round"
        }
    }
}

struct SessionSummaryView: View {
    let summary: SessionSummary
    let startedAt: Date
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @State private var breathCountText = ""
    @State private var saved = false

    private var band: PerformanceBand? {
        summary.measuredSeconds.flatMap { AssessmentScoring.band(for: summary.kind, seconds: $0) }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: summary.isComplete ? "checkmark.circle.fill" : "flag.checkered.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(summary.isComplete ? Color.green : Color.secondary)
            Text(summary.isComplete ? "Session complete" : "Session ended")
                .font(.title.weight(.bold))
                .accessibilityIdentifier(AccessibilityID.Session.summaryTitle)
            Text(summary.title)
                .font(.headline)
                .foregroundStyle(.secondary)

            if let measured = summary.measuredSeconds {
                VStack(spacing: 8) {
                    Text(TimeFormatting.compact(measured))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .accessibilityIdentifier(AccessibilityID.Session.resultValue)
                    if let band {
                        BandBadge(band: band)
                    }
                    if summary.kind == .breathCountAssessment {
                        TextField("Number you reached", text: $breathCountText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 220)
                            .accessibilityIdentifier(AccessibilityID.Onboarding.breathCountField)
                    }
                }
                .padding()
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                HStack(spacing: 10) {
                    StatTile(title: "Time", value: TimeFormatting.clock(summary.totalElapsed))
                    StatTile(title: "Steps", value: "\(summary.completedSteps)/\(summary.stepCount)")
                    if let longest = summary.longestHold {
                        StatTile(title: "Longest hold", value: TimeFormatting.compact(longest))
                    }
                }
            }
            Spacer()
            Button {
                save()
                appModel.dismissSession()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier(AccessibilityID.Session.summaryDone)
        }
        .padding()
    }

    private func save() {
        guard !saved else { return }
        saved = true
        guard summary.isComplete || summary.completedSteps > 0 else { return }
        try? ProfileStore(context: context).recordSession(summary, startedAt: startedAt, breathCount: Int(breathCountText))
    }
}
