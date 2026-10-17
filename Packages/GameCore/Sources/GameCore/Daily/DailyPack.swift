/// Build sırasında üretilip uygulamaya gömülen günlük bulmacalar (PLAN §1.9). Sunucu yok; aynı gün
/// her cihaz aynı bulmacayı görür ve uygulama güncellemesi o günün bulmacasını değiştirmez.
public struct DailyPack: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var generatorVersion: Int
    public var startDate: DayKey
    /// `levels[i]` = `startDate + i` günü.
    public var levels: [LevelDefinition]

    public init(startDate: DayKey, levels: [LevelDefinition]) {
        schemaVersion = GameCore.schemaVersion
        generatorVersion = LevelGenerator.version
        self.startDate = startDate
        self.levels = levels
    }

    public var endDate: DayKey { startDate.adding(days: levels.count - 1) }

    /// O günün bulmacası. Paket aralığı dışında paket döngüyle tekrar kullanılır; uygulama asla boş günlük göstermez.
    public func level(for day: DayKey) -> LevelDefinition {
        let count = levels.count
        let offset = ((day.dayNumber - startDate.dayNumber) % count + count) % count
        return levels[offset]
    }
}

/// Haftanın gününe göre zorluk: Pazartesi kolay → Pazar zor. Günlük her zaman ücretsiz olduğu için yalnız
/// ücretsiz bölümlerin mekanikleri kullanılır (ok, sabit ok, engel, kesişme).
public enum DailySchedule {
    public static func profile(for day: DayKey) -> DifficultyProfile {
        switch day.isoWeekday {
        case 1: .route
        case 2, 3: .obstacle
        case 4, 5: .crossing
        default: .dailyHard
        }
    }

    /// Tarih tohumu: üretici sürümü profil adıyla zaten karışır.
    public static func seed(for day: DayKey) -> UInt64 {
        StableHash.fnv1a("daily-\(day)")
    }

    public static func build(from start: DayKey, days: Int, generator: LevelGenerator = LevelGenerator()) throws -> DailyPack {
        var levels: [LevelDefinition] = []
        for offset in 0..<days {
            let day = start.adding(days: offset)
            var level = try generator.generate(seed: seed(for: day), profile: profile(for: day)).level
            level.id = "daily-\(day)"
            levels.append(level)
        }
        return DailyPack(startDate: start, levels: levels)
    }
}
