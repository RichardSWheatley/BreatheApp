import BreatheKit
import Charts
import SwiftData
import SwiftUI

struct ProgressTabView: View {
    @Bindable var profile: UserProfile
    @Query(sort: \SessionRecord.startedAt, order: .reverse) private var sessions: [SessionRecord]
    @Query(sort: \AssessmentRecord.date) private var assessments: [AssessmentRecord]

    private var boltHistory: [AssessmentRecord] {
        assessments.filter { $0.kind == .boltAssessment }
    }

    private var completedDates: [Date] {
        sessions.filter(\.completed).map(\.startedAt)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        StatTile(title: "Streak", value: "\(TrainingStats.currentStreak(sessionDates: completedDates))", subtitle: "days")
                        StatTile(title: "This week", value: "\(TrainingStats.sessionsThisWeek(sessionDates: completedDates))", subtitle: "sessions")
                        StatTile(title: "Hold time", value: TimeFormatting.clock(TrainingStats.totalHoldTime(sessions.map(\.holdSeconds))), subtitle: "total")
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("BOLT trend") {
                    if boltHistory.count >= 2 {
                        Chart(boltHistory) { record in
                            LineMark(
                                x: .value("Date", record.date),
                                y: .value("Seconds", record.seconds)
                            )
                            .interpolationMethod(.catmullRom)
                            PointMark(
                                x: .value("Date", record.date),
                                y: .value("Seconds", record.seconds)
                            )
                        }
                        .chartYAxisLabel("seconds")
                        .frame(height: 180)
                        .padding(.vertical, 8)
                    } else {
                        Text("Re-test your BOLT score to see a trend. Two weeks between tests is the target.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Sessions") {
                    if sessions.isEmpty {
                        Text("Your completed sessions will appear here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(sessions) { record in
                        SessionRow(record: record)
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }
}

struct SessionRow: View {
    let record: SessionRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.kind?.symbolName ?? "circle")
                .foregroundStyle(record.completed ? Color.accentColor : Color.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.headline)
                Text(record.startedAt, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let measured = record.measuredSeconds {
                    Text(TimeFormatting.compact(measured))
                        .font(.headline)
                        .monospacedDigit()
                } else {
                    Text(TimeFormatting.clock(record.duration))
                        .font(.headline)
                        .monospacedDigit()
                }
                Text(record.completed ? "Completed" : "Ended early")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
