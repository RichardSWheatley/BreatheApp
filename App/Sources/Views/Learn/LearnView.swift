import BreatheKit
import SwiftUI

struct LearnView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("How it works") {
                    ForEach(Education.mechanisms) { topic in
                        NavigationLink(value: topic) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(topic.title).font(.headline)
                                    Text(topic.summary).font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: topic.symbolName)
                            }
                        }
                    }
                }
                Section("Safety") {
                    NavigationLink {
                        SafetyRulesView()
                    } label: {
                        Label(Education.safety.title, systemImage: Education.safety.symbolName)
                    }
                }
                Section("Protocols") {
                    ForEach(SessionKind.trainingProtocols + SessionKind.assessments) { kind in
                        NavigationLink(value: Education.guide(for: kind)) {
                            Label(kind.title, systemImage: kind.symbolName)
                        }
                    }
                }
            }
            .navigationTitle("Learn")
            .navigationDestination(for: EducationTopic.self) { topic in
                TopicDetailView(topic: topic)
            }
        }
    }
}
