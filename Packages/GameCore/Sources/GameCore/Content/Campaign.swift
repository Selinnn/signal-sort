/// Uygulamaya gömülen kampanya: bölümler ve sıralı seviyeler.
public struct Campaign: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var generatorVersion: Int
    public var chapters: [Chapter]

    public var levels: [LevelDefinition] { chapters.flatMap(\.levels) }

    public init(schemaVersion: Int = GameCore.schemaVersion, generatorVersion: Int = LevelGenerator.version, chapters: [Chapter]) {
        self.schemaVersion = schemaVersion
        self.generatorVersion = generatorVersion
        self.chapters = chapters
    }
}

public struct Chapter: Codable, Hashable, Sendable {
    public var id: String
    public var profile: String
    public var levels: [LevelDefinition]
}

/// `content/campaign-spec.json`: bölüm sırası, seviye sayıları, elle tasarlanan seviyeler ve tohum tabanları.
public struct CampaignSpec: Codable, Sendable {
    public struct ChapterSpec: Codable, Sendable {
        public var id: String
        public var profile: String
        public var count: Int
        /// Bölümün başına sırayla konan elle tasarlanmış seviyelerin dosya adları (uzantısız).
        public var handmade: [String]
        public var seed: UInt64
    }

    public var chapters: [ChapterSpec]
    /// Bu orandan benzer seviyeler aynı kampanyaya girmez.
    public var maxSimilarity: Double
    /// Üretilen aday havuzu, gereken seviye sayısının bu katı kadardır.
    public var poolFactor: Int
}

public struct CampaignBuildError: Error, CustomStringConvertible {
    public var description: String
}

/// Kampanyayı kurar (PLAN §6): elle seviyeler + profil başına aday havuzu → benzerlik eleme →
/// arama düğümüne göre zorluk sıralaması → her 5. seviyede bir "nefes" (kolay) seviye.
public struct CampaignBuilder: Sendable {
    public var generator = LevelGenerator()

    public init() {}

    public func build(spec: CampaignSpec, handmade: [String: LevelDefinition], log: (String) -> Void = { _ in }) throws -> Campaign {
        var accepted: [LevelDefinition] = []
        var chapters: [Chapter] = []

        for (chapterIndex, chapterSpec) in spec.chapters.enumerated() {
            guard let profile = DifficultyProfile.named(chapterSpec.profile) else {
                throw CampaignBuildError(description: "Bilinmeyen profil: \(chapterSpec.profile)")
            }
            var levels: [LevelDefinition] = []
            for name in chapterSpec.handmade {
                guard var level = handmade[name] else { throw CampaignBuildError(description: "Elle seviye bulunamadı: \(name)") }
                let report = Solver().solve(level)
                guard report.isExhaustive, report.isSolvable else { throw CampaignBuildError(description: "\(name) çözülemiyor") }
                level.par = report.par
                level.solutionCount = report.solutionCount
                level.solutions = report.solutions
                let issues = LevelValidator().validate(level)
                guard issues.isEmpty else { throw CampaignBuildError(description: "\(name): \(issues)") }
                levels.append(level)
                accepted.append(level)
            }

            let needed = chapterSpec.count - levels.count
            guard needed >= 0 else { throw CampaignBuildError(description: "\(chapterSpec.id): elle seviye sayısı bölümden fazla") }
            var pool: [GeneratedLevel] = []
            var seed = chapterSpec.seed
            let seedLimit = chapterSpec.seed + UInt64(max(needed, 1) * spec.poolFactor * 20)
            while pool.count < needed * spec.poolFactor && seed < seedLimit {
                defer { seed += 1 }
                guard let generated = try? generator.generate(seed: seed, profile: profile) else { continue }
                let tooSimilar = (accepted + pool.map(\.level)).contains {
                    LevelFingerprint.similarity(generated.level, $0) >= spec.maxSimilarity
                }
                if !tooSimilar { pool.append(generated) }
            }
            guard pool.count >= needed else {
                throw CampaignBuildError(description: "\(chapterSpec.id): yalnız \(pool.count)/\(needed) benzersiz seviye üretilebildi")
            }

            // Zorluğa göre sırala, aralığı kapsayacak şekilde eşit aralıklı seç.
            pool.sort { ($0.metrics.searchNodes, $0.metrics.par, $0.level.seed ?? 0) < ($1.metrics.searchNodes, $1.metrics.par, $1.level.seed ?? 0) }
            var chosen: [GeneratedLevel] = []
            for i in 0..<needed {
                let index = needed == 1 ? 0 : i * (pool.count - 1) / (needed - 1)
                chosen.append(pool[index])
            }
            // En kolay beşte biri "nefes" seviyesi olur ve her 5. sıraya yerleşir.
            let breatherCount = needed / 5
            let breathers = Array(chosen.prefix(breatherCount))
            var main = Array(chosen.dropFirst(breatherCount))
            var ordered: [LevelDefinition] = []
            var breatherIterator = breathers.makeIterator()
            while ordered.count < needed {
                let position = levels.count + ordered.count + 1
                if position % 5 == 0, let breather = breatherIterator.next() {
                    ordered.append(breather.level)
                } else if !main.isEmpty {
                    ordered.append(main.removeFirst().level)
                } else if let breather = breatherIterator.next() {
                    ordered.append(breather.level)
                }
            }
            accepted.append(contentsOf: ordered)
            levels.append(contentsOf: ordered)

            for index in levels.indices {
                levels[index].id = "c\(chapterIndex + 1)-\(index + 1 < 10 ? "0" : "")\(index + 1)"
            }
            log("\(chapterSpec.id): \(levels.count) seviye (\(chapterSpec.handmade.count) elle), havuz \(pool.count), son tohum \(seed - 1)")
            chapters.append(Chapter(id: chapterSpec.id, profile: chapterSpec.profile, levels: levels))
        }
        return Campaign(chapters: chapters)
    }
}
