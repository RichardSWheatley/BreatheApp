import BreatheKit
import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    var body: some View {
        @Bindable var appModel = appModel
        Group {
            if let profile = profiles.first {
                if profile.onboardingCompleted {
                    MainTabView(profile: profile)
                } else {
                    OnboardingFlow(profile: profile)
                }
            } else {
                ProgressView("Setting up…")
                    .task {
                        _ = try? ProfileStore(context: context).profile()
                    }
            }
        }
        .fullScreenCover(item: $appModel.activeSession) { controller in
            SessionPlayerView(controller: controller)
        }
    }
}

struct MainTabView: View {
    @Bindable var profile: UserProfile

    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max.fill") {
                HomeView(profile: profile)
            }
            Tab("Train", systemImage: "figure.mind.and.body") {
                LibraryView(profile: profile)
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                ProgressTabView(profile: profile)
            }
            Tab("Learn", systemImage: "book.fill") {
                LearnView()
            }
        }
    }
}
