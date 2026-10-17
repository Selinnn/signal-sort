public enum LevelAvailability: Equatable, Sendable {
    case available
    /// Önceki seviye (veya önceki bölümün son seviyesi) çözülmedi.
    case lockedByProgress
    /// Ücretsiz bölümlerin dışında; "Tam Oyun" gerekir (PLAN §3.3).
    case requiresFullGame
}

/// Kilit ve sıra kuralları (PLAN §3.2): bölüm içinde doğrusal; bir bölüm, önceki bölümün son seviyesi
/// çözülünce açılır; ilk `freeChapterCount` bölümden sonrası Tam Oyun ister.
public struct Progression: Sendable {
    public static let freeChapterCount = 3

    public let campaign: Campaign
    public let freeChapterCount: Int
    private let positions: [String: (chapter: Int, index: Int)]

    public init(campaign: Campaign, freeChapterCount: Int = Progression.freeChapterCount) {
        self.campaign = campaign
        self.freeChapterCount = freeChapterCount
        var positions: [String: (Int, Int)] = [:]
        for (c, chapter) in campaign.chapters.enumerated() {
            for (i, level) in chapter.levels.enumerated() { positions[level.id] = (c, i) }
        }
        self.positions = positions
    }

    public func position(of levelID: String) -> (chapter: Int, index: Int)? { positions[levelID] }

    public func chapterAvailability(_ chapter: Int, progress: PlayerProgress, fullGame: Bool) -> LevelAvailability {
        if chapter >= freeChapterCount && !fullGame { return .requiresFullGame }
        if chapter == 0 { return .available }
        guard let previousLast = campaign.chapters[chapter - 1].levels.last else { return .available }
        return progress.isCompleted(previousLast.id) ? .available : .lockedByProgress
    }

    public func availability(of levelID: String, progress: PlayerProgress, fullGame: Bool) -> LevelAvailability {
        guard let (chapter, index) = positions[levelID] else { return .lockedByProgress }
        let chapterState = chapterAvailability(chapter, progress: progress, fullGame: fullGame)
        guard chapterState == .available else { return chapterState }
        if index == 0 || progress.isCompleted(levelID) { return .available }
        return progress.isCompleted(campaign.chapters[chapter].levels[index - 1].id) ? .available : .lockedByProgress
    }

    /// Kampanya sırasında bir sonraki seviye (bölüm sınırını geçer). Son seviyeden sonra nil.
    public func level(after levelID: String) -> LevelDefinition? {
        guard let (chapter, index) = positions[levelID] else { return nil }
        let levels = campaign.chapters[chapter].levels
        if index + 1 < levels.count { return levels[index + 1] }
        return campaign.chapters.dropFirst(chapter + 1).first { !$0.levels.isEmpty }?.levels.first
    }

    /// "Devam et": sıradaki ilk açık ve çözülmemiş seviye. Hepsi bittiyse veya kalanlar kilitliyse nil.
    public func continueLevel(progress: PlayerProgress, fullGame: Bool) -> LevelDefinition? {
        campaign.levels.first {
            !progress.isCompleted($0.id) && availability(of: $0.id, progress: progress, fullGame: fullGame) == .available
        }
    }

    public func completedCount(chapter: Int, progress: PlayerProgress) -> Int {
        campaign.chapters[chapter].levels.filter { progress.isCompleted($0.id) }.count
    }

    public func stars(chapter: Int, progress: PlayerProgress) -> Int {
        campaign.chapters[chapter].levels.reduce(0) { $0 + progress.stars($1.id) }
    }

    public func totalStars(progress: PlayerProgress) -> Int {
        campaign.chapters.indices.reduce(0) { $0 + stars(chapter: $1, progress: progress) }
    }
}
