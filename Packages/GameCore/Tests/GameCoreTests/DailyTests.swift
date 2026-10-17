import Foundation
import Testing
@testable import GameCore

@Suite struct DayKeyTests {
    @Test func parsesOnlyRealDates() {
        #expect(DayKey("2026-10-17") == DayKey(year: 2026, month: 10, day: 17))
        #expect(DayKey("2028-02-29") != nil)
        #expect(DayKey("2026-02-29") == nil)
        #expect(DayKey("2026-13-01") == nil)
        #expect(DayKey("2026-10") == nil)
        #expect(DayKey("abc") == nil)
    }

    @Test func dayNumbersMatchKnownDates() {
        #expect(DayKey("1970-01-01")!.dayNumber == 0)
        #expect(DayKey("2000-03-01")!.dayNumber == 11_017)
        #expect(DayKey("1969-12-31")!.dayNumber == -1)
        for n in stride(from: -50_000, through: 100_000, by: 37) {
            #expect(DayKey(dayNumber: n).dayNumber == n)
        }
    }

    @Test func weekdaysAndArithmetic() {
        #expect(DayKey("2026-10-17")!.isoWeekday == 6)  // Cumartesi
        #expect(DayKey("2026-11-01")!.isoWeekday == 7)  // Pazar
        #expect(DayKey("2026-11-02")!.isoWeekday == 1)  // Pazartesi
        #expect(DayKey("2026-12-31")!.adding(days: 1) == DayKey("2027-01-01"))
        #expect(DayKey("2028-03-01")!.adding(days: -1) == DayKey("2028-02-29"))
        #expect(DayKey("0999-01-05")!.description == "0999-01-05")
    }

    @Test func codesAsString() throws {
        let data = try JSONEncoder().encode([DayKey("2026-11-01")!])
        #expect(String(decoding: data, as: UTF8.self) == "[\"2026-11-01\"]")
        #expect(throws: DecodingError.self) { try JSONDecoder().decode([DayKey].self, from: Data("[\"2026-02-30\"]".utf8)) }
    }
}

@Suite struct DailyPackTests {
    @Test func cyclesOutsideThePackRange() {
        let levels = (0..<3).map { LevelDefinition(id: "d\($0)", width: 3, height: 3, sources: [], receivers: []) }
        let pack = DailyPack(startDate: DayKey("2026-11-01")!, levels: levels)
        #expect(pack.endDate == DayKey("2026-11-03"))
        #expect(pack.level(for: DayKey("2026-11-02")!).id == "d1")
        #expect(pack.level(for: DayKey("2026-11-04")!).id == "d0")
        #expect(pack.level(for: DayKey("2026-10-31")!).id == "d2")
    }

    @Test func weekdaysGetHarderTowardSunday() {
        let monday = DayKey("2026-11-02")!
        #expect((0..<7).map { DailySchedule.profile(for: monday.adding(days: $0)).name } ==
            ["route", "obstacle", "obstacle", "crossing", "crossing", "daily-hard", "daily-hard"])
    }
}

@Suite struct DailyProgressTests {
    let today = DayKey("2026-11-10")!

    @Test func streakIsGentle() {
        var progress = PlayerProgress()
        #expect(progress.dailyStreak(today: today) == 0)
        for back in [1, 2, 3, 5] { progress.recordDaily(today.adding(days: -back), moves: 3, stars: 3, hintUsed: false) }
        // Bugün henüz oynanmadı: seri dünden sayılır ve bozulmaz.
        #expect(progress.dailyStreak(today: today) == 3)
        progress.recordDaily(today, moves: 4, stars: 2, hintUsed: true)
        #expect(progress.dailyStreak(today: today) == 4)
        // Bir gün kaçırılınca sayaç sıfırdan başlar.
        #expect(progress.dailyStreak(today: today.adding(days: 2)) == 0)
    }

    @Test func keepsTheBestDailyResult() {
        var progress = PlayerProgress()
        progress.recordDaily(today, moves: 6, stars: 2, hintUsed: true)
        let improved = progress.recordDaily(today, moves: 4, stars: 3, hintUsed: false)
        let worse = progress.recordDaily(today, moves: 9, stars: 1, hintUsed: false)
        #expect(improved && !worse)
        #expect(progress.dailyRecords[today] == LevelRecord(stars: 3, bestMoves: 4, hintUsed: false))
    }

    @Test func versionOneSavesStillLoad() throws {
        let v1 = #"{"schemaVersion":1,"records":{"c1-01":{"stars":3,"bestMoves":1,"hintUsed":false}},"lastPlayedLevelID":"c1-01"}"#
        let progress = try JSONDecoder().decode(PlayerProgress.self, from: Data(v1.utf8)).migrated()
        #expect(progress.schemaVersion == PlayerProgress.currentSchemaVersion)
        #expect(progress.records["c1-01"]?.stars == 3)
        #expect(progress.dailyRecords.isEmpty)
        var withDaily = progress
        withDaily.recordDaily(today, moves: 1, stars: 3, hintUsed: false)
        let again = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(withDaily))
        #expect(again == withDaily)
    }
}

/// CI içerik testi: gömülü günlük paketi.
@Suite struct DailyContentTests {
    let pack: DailyPack

    init() throws {
        pack = try ContentTests.load(DailyPack.self, "SignalSort/Resources/Levels/dailies.json")
    }

    @Test func coversTwoYearsWithMatchingIDsAndProfiles() {
        #expect(pack.levels.count == 730)
        #expect(pack.startDate == DayKey("2026-11-01"))
        #expect(pack.generatorVersion == LevelGenerator.version)
        for (offset, level) in pack.levels.enumerated() {
            let day = pack.startDate.adding(days: offset)
            #expect(level.id == "daily-\(day)")
            #expect(level.profile == DailySchedule.profile(for: day).name, "\(level.id)")
        }
    }

    @Test func usesOnlyFreeMechanicsAndRecordedSolutionsWork() {
        let engine = SimulationEngine()
        let free: Set<TileKind> = [.router, .blocker]
        for level in pack.levels {
            #expect(level.tiles.allSatisfy { free.contains($0.kind) }, "\(level.id)")
            #expect(LevelValidator().validate(level) == [], "\(level.id)")
            guard let best = level.solutions?.first else {
                Issue.record("\(level.id): çözüm yok")
                continue
            }
            #expect(level.par == best.moves)
            #expect(engine.simulate(level, best.state(in: level)).isSuccess, "\(level.id)")
        }
    }

    @Test func firstWeekRebuildsIdentically() throws {
        let rebuilt = try DailySchedule.build(from: pack.startDate, days: 7)
        #expect(rebuilt.levels == Array(pack.levels.prefix(7)))
    }
}
