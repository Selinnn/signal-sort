import SwiftUI

@main
struct SignalSortApp: App {
    @State private var store: ProgressStore
    @State private var shop: StoreService

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestFastPlayback") { GameSession.tickScale = 0.05 }
        let store = ProgressStore(catalog: .bundled, dailies: .bundled)
        #if DEBUG
        if arguments.contains("-resetProgress") { store.reset() }
        if arguments.contains("-unlockAll") { store.unlockAll = true }
        if let index = arguments.firstIndex(of: "-hints"), index + 1 < arguments.count, let hints = Int(arguments[index + 1]) {
            store.setHintBalance(hints)
        }
        #endif
        _store = State(initialValue: store)
        _shop = State(initialValue: StoreService(progress: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, shop: shop)
                .task { await shop.start() }
        }
    }
}
