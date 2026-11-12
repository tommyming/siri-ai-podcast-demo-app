import SwiftUI

@main
struct PodcastDemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(AppModel.shared)
        }
    }
}
