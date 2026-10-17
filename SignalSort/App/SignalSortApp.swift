import SwiftUI

@main
struct SignalSortApp: App {
    @State private var store: ProgressStore

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestFastPlayback") { GameSession.tickScale = 0.05 }
        let store = ProgressStore(catalog: .bundled, dailies: .bundled)
        #if DEBUG
        if arguments.contains("-resetProgress") { store.reset() }
        if arguments.contains("-unlockAll") { store.unlockAll = true }
        #endif
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
