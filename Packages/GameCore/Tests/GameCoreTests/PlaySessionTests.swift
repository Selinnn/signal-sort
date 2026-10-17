import Testing
@testable import GameCore

@Suite struct PlaySessionTests {
    var session = PlaySession(level: {
        var level = Fixtures.schemaExample
        level.par = 3
        return level
    }())

    @Test mutating func solvingAwardsStarsAndLocksTheBoard() {
        for _ in 0..<3 {
            let rotated = session.rotate("r1")
            #expect(rotated)
        }
        #expect(session.moves == 3)
        let solved = session.run()
        #expect(solved.isSuccess)
        #expect(session.isSolved)
        #expect(session.stars == 3)
        let rotatedAfterSolve = session.rotate("r1")
        #expect(!rotatedAfterSolve)
        #expect(!session.canUndo)
        #expect(session.runCount == 1)
    }

    @Test mutating func extraTurnsCostStars() {
        for _ in 0..<7 { session.rotate("r1") }
        #expect(session.moves == 3)
        session.run()
        #expect(session.stars == 3)
    }

    @Test mutating func fixedAndNonDirectionalTilesCannotRotate() {
        for id in ["r2", "b1", "nope"] {
            let rotated = session.rotate(id)
            #expect(!rotated)
        }
        #expect(session.history.isEmpty)
    }

    @Test mutating func undoAndResetWalkTheHistory() {
        session.rotate("r1")
        session.rotate("r1")
        session.undo()
        #expect(session.moves == 1)
        session.reset()
        #expect(session.state == .initial)
        #expect(!session.canReset)
        session.undo()
        #expect(session.moves == 1)
    }

    @Test mutating func failedRunKeepsResultUntilTheBoardChanges() {
        let result = session.run()
        #expect(!result.isSuccess)
        #expect(session.lastResult == result)
        session.rotate("r1")
        #expect(session.lastResult == nil)
    }

    @Test mutating func hintFixesATileAndCapsStars() {
        let hint = session.takeHint()
        #expect(hint?.tileID == "r1")
        #expect(session.hintsUsed == 1)
        let result = session.run()
        #expect(result.isSuccess)
        #expect(session.stars == Scoring.maxStarsWithHint)
        let after = session.takeHint()
        #expect(after == nil)
    }
}
