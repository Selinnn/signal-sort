import Foundation
import Testing
@testable import GameCore

@Suite struct PlayerProgressTests {
    @Test func keepsTheBestResult() {
        var progress = PlayerProgress()
        let results = [
            progress.record(levelID: "a", moves: 7, stars: 1, hintUsed: true),
            progress.record(levelID: "a", moves: 5, stars: 2, hintUsed: false),
            progress.record(levelID: "a", moves: 9, stars: 1, hintUsed: false),
            progress.record(levelID: "a", moves: 4, stars: 2, hintUsed: false),
        ]
        #expect(results == [true, true, false, true])
        #expect(progress.records["a"] == LevelRecord(stars: 2, bestMoves: 4, hintUsed: false))
        #expect(progress.lastPlayedLevelID == "a")
    }

    @Test func roundTripsAndMigrates() throws {
        var progress = PlayerProgress(schemaVersion: 0)
        progress.record(levelID: "c1-01", moves: 1, stars: 3, hintUsed: false)
        let decoded = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(progress))
        #expect(decoded == progress)
        #expect(decoded.migrated().schemaVersion == PlayerProgress.currentSchemaVersion)
        #expect(decoded.migrated().records == progress.records)
    }
}

@Suite struct ProgressionTests {
    let campaign: Campaign
    let progression: Progression

    init() throws {
        campaign = try ContentTests.load(Campaign.self, "SignalSort/Resources/Levels/campaign.json")
        progression = Progression(campaign: campaign)
    }

    @Test func freshPlayerCanOnlyStartTheFirstLevel() {
        let fresh = PlayerProgress()
        #expect(progression.availability(of: "c1-01", progress: fresh, fullGame: false) == .available)
        #expect(progression.availability(of: "c1-02", progress: fresh, fullGame: false) == .lockedByProgress)
        #expect(progression.availability(of: "c2-01", progress: fresh, fullGame: false) == .lockedByProgress)
        #expect(progression.availability(of: "c4-01", progress: fresh, fullGame: false) == .requiresFullGame)
        #expect(progression.availability(of: "c4-01", progress: fresh, fullGame: true) == .lockedByProgress)
        #expect(progression.continueLevel(progress: fresh, fullGame: false)?.id == "c1-01")
        #expect(progression.level(after: "c1-20")?.id == "c2-01")
        #expect(progression.level(after: "c6-30") == nil)
    }

    /// Bot oyuncu tüm kampanyayı sırayla, yalnız açık seviyeleri oynayarak 3 yıldızla bitirir.
    @Test func botFinishesTheWholeCampaignWithFullGame() {
        var progress = PlayerProgress()
        let bot = BotPlayer()
        for level in campaign.levels {
            #expect(progression.continueLevel(progress: progress, fullGame: true)?.id == level.id)
            #expect(progression.availability(of: level.id, progress: progress, fullGame: true) == .available, "\(level.id)")
            let session = bot.play(level, strategy: .bestSolution)
            #expect(session.isSolved, "\(level.id)")
            #expect(session.stars == 3, "\(level.id)")
            #expect(session.moves == level.par, "\(level.id)")
            progress.record(levelID: level.id, moves: session.moves, stars: session.stars ?? 0, hintUsed: session.hintUsed)
        }
        #expect(progression.continueLevel(progress: progress, fullGame: true) == nil)
        #expect(progression.totalStars(progress: progress) == campaign.levels.count * 3)
    }

    @Test func freeTierStopsAtTheFullGameBoundary() {
        var progress = PlayerProgress()
        let bot = BotPlayer()
        while let level = progression.continueLevel(progress: progress, fullGame: false) {
            let session = bot.play(level, strategy: .bestSolution)
            progress.record(levelID: level.id, moves: session.moves, stars: session.stars ?? 0, hintUsed: false)
        }
        #expect(progress.records.count == 70)
        #expect(progression.completedCount(chapter: 2, progress: progress) == 25)
        #expect(progression.availability(of: "c4-01", progress: progress, fullGame: false) == .requiresFullGame)
        #expect(progression.availability(of: "c4-01", progress: progress, fullGame: true) == .available)
    }

    /// İpucu sistemi her seviyede tek başına çözüme götürmeli; ipucuyla en fazla 2★.
    @Test func hintsAloneSolveEveryLevel() {
        let bot = BotPlayer()
        for level in campaign.levels {
            let session = bot.play(level, strategy: .hintsOnly)
            #expect(session.isSolved, "\(level.id)")
            #expect((session.stars ?? 0) <= Scoring.maxStarsWithHint, "\(level.id)")
            #expect(session.hintsUsed >= 1, "\(level.id)")
        }
    }
}
