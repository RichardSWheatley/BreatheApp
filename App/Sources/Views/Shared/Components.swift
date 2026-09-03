import BreatheKit
import SwiftUI

struct BandBadge: View {
    let band: PerformanceBand

    var body: some View {
        Text(band.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(PhaseStyle.color(for: band).opacity(0.18), in: Capsule())
            .foregroundStyle(PhaseStyle.color(for: band))
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Baseline card for one assessment: value and band.
struct BaselineTile: View {
    let kind: SessionKind
    let seconds: TimeInterval?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(kind.shortTitle, systemImage: kind.symbolName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let seconds {
                Text(TimeFormatting.compact(seconds))
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                if let band = AssessmentScoring.band(for: kind, seconds: seconds) {
                    BandBadge(band: band)
                }
            } else {
                Text("—")
                    .font(.title2.weight(.semibold))
                Text("Not tested")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct TopicDetailView: View {
    let topic: EducationTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: topic.symbolName)
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                Text(topic.summary)
                    .font(.headline)
                ForEach(Array(topic.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(.body)
                }
            }
            .padding()
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Human readable outline of a plan: table rows for apnea tables, a
/// one-line description for everything else.
struct PlanOutlineView: View {
    let plan: SessionPlan

    private struct TableRow: Identifiable {
        let round: Int
        let breathe: TimeInterval
        let hold: TimeInterval
        var id: Int { round }
    }

    private var rows: [TableRow] {
        guard plan.kind == .co2Table || plan.kind == .o2Table, plan.roundCount > 0 else { return [] }
        return (1...plan.roundCount).compactMap { round in
            let steps = plan.steps.filter { $0.round == round }
            guard let breathe = steps.first(where: { $0.phase == .recover })?.duration,
                  let hold = steps.first(where: { $0.phase.isHold })?.duration else { return nil }
            return TableRow(round: round, breathe: breathe, hold: hold)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !rows.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow {
                        Text("Round").font(.caption).foregroundStyle(.secondary)
                        Text("Breathe").font(.caption).foregroundStyle(.secondary)
                        Text("Hold").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(rows) { row in
                        GridRow {
                            Text("\(row.round)")
                            Text(TimeFormatting.clock(row.breathe))
                            Text(TimeFormatting.clock(row.hold))
                        }
                        .monospacedDigit()
                    }
                }
            } else {
                Text(description)
            }
            Text("Planned time: \(TimeFormatting.clock(plan.plannedDuration))" + (plan.isOpenEnded ? " plus your hold" : ""))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var description: String {
        switch plan.kind {
        case .cadence:
            let inhale = plan.steps.first { $0.phase == .inhale }?.duration ?? 4
            let hold = plan.steps.first { $0.phase == .holdFull }?.duration ?? 6
            let exhale = plan.steps.first { $0.phase == .exhale }?.duration ?? 4
            return "\(plan.roundCount) rounds of inhale \(Int(inhale)) s · hold \(Int(hold)) s · exhale \(Int(exhale)) s · hold \(Int(hold)) s"
        case .hypoxicSprints:
            let walk = plan.steps.first { $0.phase == .walkHold }
            let paces = walk?.paces ?? 0
            let seconds = Int(walk?.duration ?? 0)
            return "\(plan.roundCount) reps of a \(paces)-pace walking hold (about \(seconds) s) with 1 minute of recovery"
        case .imt:
            let reps = plan.steps.first { $0.phase == .resistedInhale }?.repCount ?? 15
            return "\(plan.roundCount) sets of \(reps) forceful inhales, 1 minute rest between sets"
        case .boltAssessment:
            return "Normal inhale, normal exhale, then hold until the first urge to breathe"
        case .maxHoldAssessment:
            return "Three deep breaths, then hold on full lungs until you must exhale"
        case .breathCountAssessment:
            return "Inhale fully, then count aloud on one breath until empty"
        case .co2Table, .o2Table:
            return ""
        }
    }
}
