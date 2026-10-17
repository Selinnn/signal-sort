import Foundation
import Testing
@testable import GameCore

@Suite struct HintEconomyTests {
    @Test func newPlayersStartWithThreeHintsAndCanSpendThem() {
        var progress = PlayerProgress()
        #expect(progress.hintBalance == HintEconomy.startingHints)
        var spent = 0
        while progress.spendHint() { spent += 1 }
        #expect(spent == 3)
        #expect(progress.hintBalance == 0)
    }

    @Test func dailyRewardIsGivenOncePerDay() {
        var progress = PlayerProgress(hintBalance: 0)
        let day = DayKey("2026-11-02")!
        progress.recordDaily(day, moves: 5, stars: 2, hintUsed: false)
        progress.recordDaily(day, moves: 4, stars: 3, hintUsed: false)
        #expect(progress.hintBalance == 1)
        progress.recordDaily(day.adding(days: 1), moves: 4, stars: 3, hintUsed: false)
        #expect(progress.hintBalance == 2)
    }

    @Test func purchasesAreAppliedExactlyOnce() {
        var progress = PlayerProgress(hintBalance: 0)
        let first = progress.applyHintPurchase(transactionID: 42, hints: HintEconomy.packSize)
        let redelivered = progress.applyHintPurchase(transactionID: 42, hints: HintEconomy.packSize)
        let second = progress.applyHintPurchase(transactionID: 43, hints: HintEconomy.packSize)
        #expect([first, redelivered, second] == [10, 0, 10] as [Int])
        #expect(progress.hintBalance == 20)
    }

    @Test func fullGameBonusIsGrantedOnce() {
        var progress = PlayerProgress(hintBalance: 1)
        let granted = [progress.grantFullGameBonusIfNeeded(), progress.grantFullGameBonusIfNeeded()]
        #expect(granted == [20, 0])
        #expect(progress.hintBalance == 21)
    }

    @Test func olderSavesGetStartingHintsAndLedgerSurvivesRoundTrip() throws {
        let v2 = #"{"schemaVersion":2,"records":{},"dailyRecords":{"2026-11-02":{"stars":3,"bestMoves":4,"hintUsed":false}}}"#
        var progress = try JSONDecoder().decode(PlayerProgress.self, from: Data(v2.utf8)).migrated()
        #expect(progress.schemaVersion == 3)
        #expect(progress.hintBalance == HintEconomy.startingHints)
        #expect(progress.dailyRecords.count == 1)
        progress.applyHintPurchase(transactionID: 7, hints: 10)
        progress.grantFullGameBonusIfNeeded()
        let again = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(progress))
        #expect(again == progress)
        #expect(again.grantedTransactionIDs == [7])
    }
}
