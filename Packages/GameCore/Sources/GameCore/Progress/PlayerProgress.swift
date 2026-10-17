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
    /// 1: kampanya kayıtları. 2: günlük bulmaca kayıtları eklendi.
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    /// Seviye ID → en iyi sonuç. Yalnız çözülmüş seviyeler bulunur.
    public var records: [String: LevelRecord]
    public var lastPlayedLevelID: String?
    /// Günlük bulmaca: gün → en iyi sonuç.
    public var dailyRecords: [DayKey: LevelRecord]

    public init(
        schemaVersion: Int = PlayerProgress.currentSchemaVersion,
        records: [String: LevelRecord] = [:],
        lastPlayedLevelID: String? = nil,
        dailyRecords: [DayKey: LevelRecord] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.records = records
        self.lastPlayedLevelID = lastPlayedLevelID
        self.dailyRecords = dailyRecords
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, records, lastPlayedLevelID, dailyRecords }

    /// Eski sürümlerde olmayan alanlar boş kabul edilir; böylece güncelleme sonrası ilerleme kaybolmaz.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        records = try c.decodeIfPresent([String: LevelRecord].self, forKey: .records) ?? [:]
        lastPlayedLevelID = try c.decodeIfPresent(String.self, forKey: .lastPlayedLevelID)
        let daily = try c.decodeIfPresent([String: LevelRecord].self, forKey: .dailyRecords) ?? [:]
        dailyRecords = Dictionary(uniqueKeysWithValues: daily.compactMap { key, value in DayKey(key).map { ($0, value) } })
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(records, forKey: .records)
        try c.encodeIfPresent(lastPlayedLevelID, forKey: .lastPlayedLevelID)
        try c.encode(Dictionary(uniqueKeysWithValues: dailyRecords.map { ($0.key.description, $0.value) }), forKey: .dailyRecords)
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

    @discardableResult
    public mutating func recordDaily(_ day: DayKey, moves: Int, stars: Int, hintUsed: Bool) -> Bool {
        let new = LevelRecord(stars: stars, bestMoves: moves, hintUsed: hintUsed)
        guard let old = dailyRecords[day] else {
            dailyRecords[day] = new
            return true
        }
        let better = stars > old.stars || (stars == old.stars && moves < old.bestMoves)
        if better { dailyRecords[day] = new }
        return better
    }

    /// Nazik seri: bugün çözüldüyse bugünden, çözülmediyse dünden geriye kesintisiz çözülen gün sayısı.
    /// Bugünü henüz oynamamak seriyi bozmaz; kaçırılan gün yalnız sayacı sıfırlar, ceza yoktur.
    public func dailyStreak(today: DayKey) -> Int {
        var day = dailyRecords[today] != nil ? today : today.adding(days: -1)
        var streak = 0
        while dailyRecords[day] != nil {
            streak += 1
            day = day.adding(days: -1)
        }
        return streak
    }

    /// Eski şema sürümlerini günceller. Bilinmeyen gelecek sürüm olduğu gibi korunur.
    public func migrated() -> PlayerProgress {
        var copy = self
        if copy.schemaVersion < Self.currentSchemaVersion { copy.schemaVersion = Self.currentSchemaVersion }
        return copy
    }
}
