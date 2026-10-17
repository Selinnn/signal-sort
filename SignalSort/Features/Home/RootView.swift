import GameCore
import SwiftUI

enum AppRoute: Hashable {
    case chapters
    case chapter(Int)
    case level(String)
    case daily
    case dailyLevel(DayKey)
}

/// Uygulamanın gezinme kökü: Home → Bölümler → Bölüm → Seviye.
struct RootView: View {
    let store: ProgressStore
    let shop: StoreService
    let ads: AdsCoordinator
    @State private var path: [AppRoute] = []
    @State private var showStore = false
    @State private var today = DayKey.today()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(store: store, today: today, path: $path, showStore: { showStore = true })
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .chapters:
                        ChapterMapView(store: store, path: $path, showStore: { showStore = true })
                    case .chapter(let index):
                        ChapterLevelsView(store: store, chapterIndex: index, path: $path)
                    case .level(let id):
                        if let level = store.catalog.level(withID: id) {
                            BoardScreen(level: level, mode: .campaign(number: store.catalog.number(of: id)), store: store,
                                        ads: ads, today: today, onNext: { next(after: id) }, showStore: { showStore = true })
                                .id(id)
                        }
                    case .daily:
                        DailyView(store: store, today: today, path: $path)
                    case .dailyLevel(let day):
                        if let level = store.dailies.level(for: day) {
                            BoardScreen(level: level, mode: .daily(day), store: store, ads: ads, today: today,
                                        onNext: { path.removeLast() }, showStore: { showStore = true })
                                .id(day)
                        }
                    }
                }
        }
        .sheet(isPresented: $showStore) { StoreView(shop: shop, store: store) }
        .sheet(isPresented: Binding(get: { ads.consent.showsTrackingExplainer }, set: { ads.consent.showsTrackingExplainer = $0 })) {
            TrackingExplainerView { Task { await ads.consent.requestTracking() } }
        }
        .overlay {
            if let mock = ads.service as? MockAdService { MockAdOverlay(service: mock) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            Task { @MainActor in today = DayKey.today() }
        }
        .preferredColorScheme(.dark)
        .tint(Color.accentColor)
    }

    /// Sonuç → "Sonraki": reklam sırası (tutorial sonunda onay, kurallar izin verirse geçiş reklamı), sonra gezinme.
    private func next(after id: String) {
        ads.campaignLevelCompleted()
        Task {
            if id == Self.tutorialFinaleID { await ads.ensureConsent() }
            if !showStore {
                await ads.maybeShowInterstitial(completedCampaignLevels: store.progress.records.count, hasRemoveAds: store.hasRemoveAds)
            }
            navigate(after: id)
        }
    }

    /// Tutorial'ın son seviyesi: reklam onayı (UMP + ATT) bundan sonra istenir.
    static let tutorialFinaleID = "c1-05"

    /// Sonraki seviye açıksa ona geçer; Tam Oyun gerekiyorsa veya kampanya bittiyse bölüm haritasına döner.
    private func navigate(after id: String) {
        guard let next = store.progression.level(after: id) else {
            path = [.chapters]
            return
        }
        switch store.availability(of: next.id) {
        case .available:
            break
        case .requiresFullGame:
            path = [.chapters]
            showStore = true
            return
        case .lockedByProgress:
            path = [.chapters]
            return
        }
        path.removeLast()
        path.append(.level(next.id))
    }
}
