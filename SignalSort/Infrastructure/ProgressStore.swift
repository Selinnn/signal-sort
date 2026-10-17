import Foundation
import GameCore
import Observation

/// Oyuncu ilerlemesini UserDefaults'ta JSON olarak saklar ve kilit kurallarını uygulamaya açar.
@MainActor
@Observable
final class ProgressStore {
    static let storageKey = "playerProgress"

    let catalog: LevelCatalog
    let dailies: DailyCatalog
    let progression: Progression
    private(set) var progress: PlayerProgress
    /// Tam Oyun hakkı; `StoreService` doğrulanmış işlemlerden ayarlar.
    var hasFullGame = false
    /// Reklamları Kaldır veya Tam Oyun (adım 11'de geçiş reklamlarını kapatır).
    var hasRemoveAds = false
    /// Yalnız DEBUG: tüm seviyeleri açar (görsel kontrol ve UI testleri).
    var unlockAll = false

    @ObservationIgnored private let defaults: UserDefaults

    init(catalog: LevelCatalog, dailies: DailyCatalog, defaults: UserDefaults = .standard) {
        self.catalog = catalog
        self.dailies = dailies
        self.defaults = defaults
        progression = Progression(campaign: catalog.campaign)
        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(PlayerProgress.self, from: data) {
            progress = stored.migrated()
        } else {
            progress = PlayerProgress()
        }
    }

    func availability(of levelID: String) -> LevelAvailability {
        unlockAll ? .available : progression.availability(of: levelID, progress: progress, fullGame: hasFullGame)
    }

    func chapterAvailability(_ chapter: Int) -> LevelAvailability {
        unlockAll ? .available : progression.chapterAvailability(chapter, progress: progress, fullGame: hasFullGame)
    }

    var continueLevel: LevelDefinition? {
        progression.continueLevel(progress: progress, fullGame: hasFullGame || unlockAll)
    }

    /// Ücretsiz bölümler bitti ve sıradaki seviye Tam Oyun istiyor mu.
    var isWaitingForFullGame: Bool {
        continueLevel == nil && progression.continueLevel(progress: progress, fullGame: true) != nil
    }

    var totalStars: Int { progression.totalStars(progress: progress) }
    var maxStars: Int { catalog.levels.count * 3 }

    /// Çözülen seviyeyi kaydeder. Yeni en iyi sonuçsa true.
    @discardableResult
    func record(_ session: PlaySession) -> Bool {
        guard session.isSolved, let stars = session.stars else { return false }
        let improved = progress.record(levelID: session.level.id, moves: session.moves, stars: stars, hintUsed: session.hintUsed)
        save()
        return improved
    }

    @discardableResult
    func recordDaily(_ day: DayKey, _ session: PlaySession) -> Bool {
        guard session.isSolved, let stars = session.stars else { return false }
        let improved = progress.recordDaily(day, moves: session.moves, stars: stars, hintUsed: session.hintUsed)
        save()
        return improved
    }

    func dailyStreak(today: DayKey) -> Int { progress.dailyStreak(today: today) }

    // MARK: İpucu ekonomisi

    var hintBalance: Int { progress.hintBalance }

    func spendHint() -> Bool {
        guard progress.spendHint() else { return false }
        save()
        return true
    }

    func grantHints(_ count: Int) {
        progress.grantHints(count)
        save()
    }

    func applyHintPurchase(transactionID: UInt64, hints: Int) {
        if progress.applyHintPurchase(transactionID: transactionID, hints: hints) > 0 { save() }
    }

    func grantFullGameBonusIfNeeded() {
        if progress.grantFullGameBonusIfNeeded() > 0 { save() }
    }

    #if DEBUG
    /// Kampanyanın ilk `count` seviyesini 3★ çözülmüş sayar (UI testleri için).
    func seedCompletedLevels(_ count: Int) {
        for level in catalog.levels.prefix(count) {
            progress.record(levelID: level.id, moves: level.par ?? 0, stars: 3, hintUsed: false)
        }
        save()
    }

    func setHintBalance(_ value: Int) {
        progress.hintBalance = value
        save()
    }
    #endif

    func reset() {
        progress = PlayerProgress()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(progress) { defaults.set(data, forKey: Self.storageKey) }
    }
}
