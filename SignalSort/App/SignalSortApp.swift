import GameCore
import SwiftUI

@main
struct SignalSortApp: App {
    @State private var store: ProgressStore
    @State private var shop: StoreService
    @State private var ads: AdsCoordinator
    /// UI testlerinde (hızlı oynatma) giriş animasyonu atlanır.
    @State private var showSplash = !ProcessInfo.processInfo.arguments.contains("-uiTestFastPlayback")

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestFastPlayback") { GameSession.tickScale = 0.05 }
        let store = ProgressStore(catalog: .bundled, dailies: .bundled)
        #if DEBUG
        if arguments.contains("-resetProgress") { store.reset() }
        if arguments.contains("-unlockAll") {
            store.unlockAll = true
            ThemeManager.shared.fullGameUnlocked = true
        }
        if let index = arguments.firstIndex(of: "-theme"), index + 1 < arguments.count, let theme = ThemeID(rawValue: arguments[index + 1]) {
            ThemeManager.shared.selection = theme
        }
        if arguments.contains("-resetProgress") { SettingsStore.shared.resetToDefaults() }
        if let index = arguments.firstIndex(of: "-hints"), index + 1 < arguments.count, let hints = Int(arguments[index + 1]) {
            store.setHintBalance(hints)
        }
        if let index = arguments.firstIndex(of: "-seedCompleted"), index + 1 < arguments.count, let count = Int(arguments[index + 1]) {
            store.seedCompletedLevels(count)
        }
        #endif
        _store = State(initialValue: store)
        _shop = State(initialValue: StoreService(progress: store))

        var useMockAds = false
        #if DEBUG
        useMockAds = arguments.contains("-mockAds")
        #endif
        let service: AdService = useMockAds ? MockAdService() : AdMobAdService()
        let ads = AdsCoordinator(service: service, consent: ConsentManager(isMock: useMockAds))
        #if DEBUG
        if arguments.contains("-resetProgress") { ads.overrideState(AdPolicyState()) }
        if arguments.contains("-adsReadyForInterstitial") {
            ads.overrideState(AdPolicyState(sessionCount: 2, levelsSinceInterstitial: 3))
        }
        #endif
        _ads = State(initialValue: ads)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView(store: store, shop: shop, ads: ads)
                if showSplash {
                    SplashView { withAnimation(.easeInOut(duration: 0.35)) { showSplash = false } }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task { await shop.start() }
            .task { await ads.appLaunched() }
        }
    }
}
