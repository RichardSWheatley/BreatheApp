import BreatheKit
import SwiftData
import SwiftUI

@main
struct BreatheApplication: App {
    private let container: ModelContainer
    @State private var appModel: AppModel

    init() {
        let launch = LaunchConfiguration.current
        let container = PersistenceController.makeContainer(inMemory: launch.usesInMemoryStore)
        PersistenceController.applyLaunchConfiguration(launch, to: container.mainContext)
        self.container = container
        _appModel = State(initialValue: AppModel(launch: launch))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
        }
        .modelContainer(container)
    }
}
