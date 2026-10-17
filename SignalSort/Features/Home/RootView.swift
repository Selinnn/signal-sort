import GameCore
import SwiftUI

enum AppRoute: Hashable {
    case chapters
    case chapter(Int)
    case level(String)
}

/// Uygulamanın gezinme kökü: Home → Bölümler → Bölüm → Seviye.
struct RootView: View {
    let store: ProgressStore
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(store: store, path: $path)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .chapters:
                        ChapterMapView(store: store, path: $path)
                    case .chapter(let index):
                        ChapterLevelsView(store: store, chapterIndex: index, path: $path)
                    case .level(let id):
                        if let level = store.catalog.level(withID: id) {
                            BoardScreen(level: level, number: store.catalog.number(of: id), store: store, onNext: { next(after: id) })
                                .id(id)
                        }
                    }
                }
        }
        .preferredColorScheme(.dark)
        .tint(Color.accentColor)
    }

    /// Sonraki seviye açıksa ona geçer; Tam Oyun gerekiyorsa veya kampanya bittiyse bölüm haritasına döner.
    private func next(after id: String) {
        guard let next = store.progression.level(after: id), store.availability(of: next.id) == .available else {
            path = [.chapters]
            return
        }
        path.removeLast()
        path.append(.level(next.id))
    }
}
