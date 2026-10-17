import SwiftUI

@main
struct SignalSortApp: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("-uiTestFastPlayback") {
            GameSession.tickScale = 0.05
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView(catalog: .bundled)
        }
    }
}
