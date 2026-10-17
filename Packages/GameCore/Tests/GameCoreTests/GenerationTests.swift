import Testing
@testable import GameCore

@Suite struct SplitMix64Tests {
    /// Referans SplitMix64 çıktıları (tohum 0). Değişirse tüm üretilen seviyeler değişir.
    @Test func matchesReferenceSequence() {
        var rng = SplitMix64(seed: 0)
        #expect((0..<5).map { _ in rng.next() } == [
            0xE220_A839_7B1D_CDAF, 0x6E78_9E6A_A1B9_65F4, 0x06C4_5D18_8009_454F, 0xF88B_B8A8_724C_81EC, 0x1B39_896A_51A8_749B,
        ])
    }

    @Test func helpersStayInRangeAndAreDeterministic() {
        var a = SplitMix64(seed: 99), b = SplitMix64(seed: 99)
        for _ in 0..<1_000 {
            let value = a.int(in: -3...7)
            #expect((-3...7).contains(value))
            #expect(value == b.int(in: -3...7))
        }
        var items = Array(0..<20), same = Array(0..<20)
        a.shuffle(&items)
        b.shuffle(&same)
        #expect(items == same)
        #expect(items.sorted() == Array(0..<20))
        #expect(a.weightedIndex([0, 0]) == nil)
        #expect(a.weightedIndex([0, 5, 0]) == 1)
    }

    @Test func stableHashIsFNV1a() {
        #expect(StableHash.fnv1a("") == 0xCBF2_9CE4_8422_2325)
        #expect(StableHash.fnv1a("a") == 0xAF63_DC4C_8601_EC8C)
    }
}

@Suite struct LevelGeneratorTests {
    let generator = LevelGenerator()

    @Test func sameSeedSameLevel() throws {
        let a = try generator.generate(seed: 7, profile: .crossing)
        let b = try generator.generate(seed: 7, profile: .crossing)
        #expect(a.level == b.level)
        let c = try generator.generate(seed: 8, profile: .crossing)
        #expect(c.level != a.level)
    }

    /// Altın tohumlar: üretici çıktısı sürüm içinde sabit kalmalı. Bu değerler bilinçli bir değişiklikle
    /// değişirse `LevelGenerator.version` artırılmalı (günlük bulmacalar ve kayıtlı seviyeler buna bağlı).
    @Test(arguments: [("route", 1 as UInt64), ("color", 1), ("toggle", 2)])
    func goldenSeeds(profile: String, seed: UInt64) throws {
        let level = try generator.generate(seed: seed, profile: DifficultyProfile.named(profile)!).level
        let fingerprint = StableHash.fnv1a(BoardRenderer.render(level) + "|\(level.par!)|\(level.solutionCount!)")
        #expect(fingerprint == GoldenSeeds.expected["\(profile)-\(seed)"], "\(profile)-\(seed) parmak izi: \(String(fingerprint, radix: 16))")
    }

    @Test(arguments: DifficultyProfile.all)
    func generatedLevelsPassValidationAndQuality(profile: DifficultyProfile) throws {
        let seeds: ClosedRange<UInt64> = ["toggle", "master"].contains(profile.name) ? 1...3 : 1...15
        for seed in seeds {
            let generated = try generator.generate(seed: seed, profile: profile)
            let level = generated.level
            #expect(LevelValidator().validate(level, deep: true) == [], "\(level.id)")
            #expect(QualityFilter().evaluate(generated.metrics, profile: profile) == [])
            #expect(level.generatorVersion == LevelGenerator.version)
            #expect(level.profile == profile.name)
            #expect(level.seed == seed)
            #expect(!SimulationEngine().simulate(level).isSuccess)
            #expect(profile.sizes.contains(BoardSize(level.width, level.height)))
            #expect(profile.signals.contains(level.sources.count))
        }
    }
}

enum GoldenSeeds {
    static let expected: [String: UInt64] = [
        "route-1": 0xD752_F77D_34A5_2B40,
        "color-1": 0xF637_D063_5F68_DF41,
        "toggle-2": 0x8007_6160_5D9F_B5BB,
    ]
}

@Suite struct QualityFilterTests {
    let base = LevelMetrics(
        signals: 2, par: 6, solutionCount: 1, searchNodes: 100, decisions: 5, scrambled: 3, sharedCells: 2,
        colorRouterShares: 1, toggleMultiEntries: 0, bridgeCrossings: 0, decoys: 1, blockers: 0)

    @Test func acceptsMetricsInsideTheProfile() {
        #expect(QualityFilter().evaluate(base, profile: .color) == [])
    }

    @Test func reportsEveryViolatedRule() {
        var metrics = base
        metrics.solutionCount = 9
        metrics.par = 30
        metrics.searchNodes = 1
        metrics.decisions = 0
        metrics.scrambled = 0
        metrics.sharedCells = 0
        metrics.colorRouterShares = 0
        var profile = DifficultyProfile.color
        profile.requirements = [.colorRouterShare, .toggleMultiEntry, .bridgeCrossing]
        #expect(QualityFilter().evaluate(metrics, profile: profile) == [
            .tooManySolutions, .parOutOfBand, .searchNodesOutOfBand, .tooFewDecisions, .tooFewScrambled, .tooFewSharedCells,
            .missingColorRouterShare, .missingToggleMultiEntry, .missingBridgeCrossing,
        ])
    }

    @Test func measuresFixtureMetrics() {
        let level = Fixtures.twoRoutes
        let metrics = LevelMetrics.measure(level, report: Solver().solve(level))!
        #expect(metrics.par == 4)
        #expect(metrics.solutionCount == 2)
        #expect(metrics.decisions == 3)
        #expect(metrics.scrambled == 2)
        #expect(metrics.decoys == 2)
        #expect(metrics.sharedCells == 0)
    }
}

@Suite struct BoardRendererTests {
    @Test func rendersSchemaExample() {
        #expect(BoardRenderer.render(Fixtures.schemaExample) == """
             ·  ·  ·  ·  · 
             ·  ·  ·  #  · 
            S→o ↓ (→) · [o]
             ·  ·  ·  ·  · 
             ·  ·  ·  ·  · 
            """)
    }
}
