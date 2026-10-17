/// Bir seviyenin en iyi sonucu.
public struct LevelRecord: Codable, Hashable, Sendable {
    public var stars: Int
    public var bestMoves: Int
    /// En iyi yıldız ipucuyla mı alındı (ipucusuz tekrar 3★ verebilir).
    public var hintUsed: Bool

    public init(stars: Int, bestMoves: Int, hintUsed: Bool) {
        self.stars = stars
        self.bestMoves = bestMoves
        self.hintUsed = hintUsed
    }
}

/// Oyuncunun kalıcı ilerlemesi. Şema sürümlüdür; eski kayıtlar `migrated()` ile güncellenir.
public struct PlayerProgress: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    /// Seviye ID → en iyi sonuç. Yalnız çözülmüş seviyeler bulunur.
    public var records: [String: LevelRecord]
    public var lastPlayedLevelID: String?

    public init(schemaVersion: Int = PlayerProgress.currentSchemaVersion, records: [String: LevelRecord] = [:], lastPlayedLevelID: String? = nil) {
        self.schemaVersion = schemaVersion
        self.records = records
        self.lastPlayedLevelID = lastPlayedLevelID
    }

    public func isCompleted(_ levelID: String) -> Bool { records[levelID] != nil }

    public func stars(_ levelID: String) -> Int { records[levelID]?.stars ?? 0 }

    /// Sonucu kaydeder; daha iyi yıldız veya daha az hamle varsa günceller. Yeni en iyi sonuçsa true.
    @discardableResult
    public mutating func record(levelID: String, moves: Int, stars: Int, hintUsed: Bool) -> Bool {
        lastPlayedLevelID = levelID
        guard let old = records[levelID] else {
            records[levelID] = LevelRecord(stars: stars, bestMoves: moves, hintUsed: hintUsed)
            return true
        }
        let better = stars > old.stars || (stars == old.stars && moves < old.bestMoves)
        if better { records[levelID] = LevelRecord(stars: stars, bestMoves: moves, hintUsed: hintUsed) }
        return better
    }

    /// Eski şema sürümlerini günceller. Bilinmeyen gelecek sürüm olduğu gibi korunur.
    public func migrated() -> PlayerProgress {
        var copy = self
        if copy.schemaVersion < Self.currentSchemaVersion { copy.schemaVersion = Self.currentSchemaVersion }
        return copy
    }
}
