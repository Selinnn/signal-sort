import Foundation
import Testing
@testable import GameCore

/// CI içerik testi (PLAN §6.7): uygulamaya gömülen kampanya geçerli, çözülebilir ve spec ile tutarlı olmalı.
/// Solver'lı tam doğrulama release'te `scripts/check-content.sh` ile koşar; burada kayıtlı çözümler tekrar oynatılır.
@Suite struct ContentTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../..").standardized

    static func load<T: Decodable>(_ type: T.Type, _ path: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: root.appendingPathComponent(path)))
    }

    let campaign: Campaign
    let spec: CampaignSpec

    init() throws {
        campaign = try Self.load(Campaign.self, "SignalSort/Resources/Levels/campaign.json")
        spec = try Self.load(CampaignSpec.self, "content/campaign-spec.json")
    }

    @Test func matchesTheSpec() {
        #expect(campaign.schemaVersion == GameCore.schemaVersion)
        #expect(campaign.generatorVersion == LevelGenerator.version)
        #expect(campaign.chapters.map(\.id) == spec.chapters.map(\.id))
        #expect(campaign.chapters.map(\.levels.count) == spec.chapters.map(\.count))
        #expect(campaign.levels.count == 150)
        let ids = campaign.levels.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(ids.first == "c1-01" && ids.last == "c6-30")
    }

    @Test func handmadeLevelsOpenTheirChapters() throws {
        for (chapter, chapterSpec) in zip(campaign.chapters, spec.chapters) {
            for (index, name) in chapterSpec.handmade.enumerated() {
                let handmade = try Self.load(LevelDefinition.self, "content/handmade/\(name).json")
                let level = chapter.levels[index]
                #expect(level.tiles == handmade.tiles && level.sources == handmade.sources && level.receivers == handmade.receivers, "\(name)")
                #expect(level.solutionCount == 1, "\(name) tek çözümlü olmalı")
            }
        }
        #expect(campaign.levels.prefix(5).map(\.par) == [1, 3, 4, 5, 3])
    }

    @Test func everyLevelIsValidAndItsRecordedSolutionsWork() {
        let engine = SimulationEngine()
        for level in campaign.levels {
            #expect(LevelValidator().validate(level) == [], "\(level.id)")
            guard let solutions = level.solutions, let best = solutions.first else {
                Issue.record("\(level.id): çözüm kaydı yok")
                continue
            }
            #expect(level.par == best.moves, "\(level.id)")
            #expect(level.solutionCount == solutions.count, "\(level.id)")
            #expect(solutions.map(\.moves) == solutions.map(\.moves).sorted(), "\(level.id)")
            for solution in solutions {
                let state = solution.state(in: level)
                #expect(state.moves == solution.moves, "\(level.id)")
                #expect(engine.simulate(level, state).isSuccess, "\(level.id)")
            }
            let hint = HintProvider().hint(level, .initial, solutions: solutions)
            #expect(hint != nil, "\(level.id): başlangıçta ipucu verilebilmeli")
        }
    }

    @Test func noTwoLevelsAreTooSimilar() {
        let levels = campaign.levels
        for i in levels.indices {
            for j in levels.indices where j > i {
                let similarity = LevelFingerprint.similarity(levels[i], levels[j])
                #expect(similarity < spec.maxSimilarity, "\(levels[i].id) ~ \(levels[j].id): \(similarity)")
            }
        }
    }

    /// Kampanya kaynaklardan yeniden üretilebilir olmalı (ilk bölüm; tamamı check-content.sh'de).
    @Test func firstChapterRebuildsIdentically() throws {
        var firstOnly = spec
        firstOnly.chapters = [spec.chapters[0]]
        var handmade: [String: LevelDefinition] = [:]
        for name in spec.chapters[0].handmade {
            handmade[name] = try Self.load(LevelDefinition.self, "content/handmade/\(name).json")
        }
        let rebuilt = try CampaignBuilder().build(spec: firstOnly, handmade: handmade)
        #expect(rebuilt.chapters[0] == campaign.chapters[0])
    }
}

@Suite struct LevelFingerprintTests {
    @Test func symmetricCopiesAreIdentical() {
        let level = Fixtures.schemaExample
        // 180° döndürülmüş kopya.
        func rotate(_ c: Coordinate) -> Coordinate { Coordinate(level.width - 1 - c.x, level.height - 1 - c.y) }
        var rotated = level
        rotated.sources = level.sources.map { Source(id: $0.id, color: $0.color, at: rotate($0.coordinate), direction: $0.direction.opposite) }
        rotated.receivers = level.receivers.map { Receiver(id: $0.id, color: $0.color, at: rotate($0.coordinate)) }
        rotated.tiles = level.tiles.map {
            Tile(id: $0.id, kind: $0.kind, at: rotate($0.coordinate), direction: $0.direction?.opposite, rotatable: $0.rotatable, color: $0.color)
        }
        #expect(LevelFingerprint.similarity(level, rotated) == 1)
        #expect(LevelFingerprint.similarity(level, Fixtures.twoRoutes) < 0.5)
    }

    @Test func transformsAreBijective() {
        for transform in 0..<8 {
            var seen: Set<Coordinate> = []
            for x in 0..<4 { for y in 0..<3 { seen.insert(LevelFingerprint.transformed(Coordinate(x, y), 4, 3, transform).0) } }
            #expect(seen.count == 12)
        }
    }
}
