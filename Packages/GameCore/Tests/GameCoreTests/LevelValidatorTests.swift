import Testing
@testable import GameCore

@Suite struct LevelValidatorTests {
    let validator = LevelValidator()

    var valid: LevelDefinition {
        var lvl = Fixtures.schemaExample
        lvl.par = 3
        lvl.solutionCount = 1
        return lvl
    }

    @Test func validLevelHasNoIssues() {
        #expect(validator.validate(valid, deep: true) == [])
    }

    @Test func structuralIssues() {
        var lvl = valid
        lvl.schemaVersion = 2
        lvl.width = 9
        lvl.tiles += [
            Tile(id: "r1", kind: .router, at: Coordinate(0, 0), direction: .north),
            Tile(id: "x", kind: .router, at: Coordinate(3, 9)),
            Tile(id: "b2", kind: .blocker, at: Coordinate(4, 4), direction: .north, rotatable: true),
            Tile(id: "c1", kind: .colorRouter, at: Coordinate(0, 4), direction: .north),
            Tile(id: "c2", kind: .colorRouter, at: Coordinate(1, 4), direction: .north, color: .pink),
            Tile(id: "g1", kind: .bridge, at: Coordinate(2, 4), color: .blue),
            Tile(id: "o", kind: .blocker, at: Coordinate(4, 2)),
        ]
        let issues = validator.validate(lvl)
        #expect(issues.contains(.unsupportedSchemaVersion(2)))
        #expect(issues.contains(.invalidSize(width: 9, height: 5)))
        #expect(issues.contains(.duplicateID("r1")))
        #expect(issues.contains(.outOfBounds(id: "x")))
        #expect(issues.contains(.missingDirection(tileID: "x")))
        #expect(issues.contains(.unexpectedDirection(tileID: "b2")))
        #expect(issues.contains(.notRotatable(tileID: "b2")))
        #expect(issues.contains(.missingColor(tileID: "c1")))
        #expect(issues.contains(.colorRouterColorNotInLevel(tileID: "c2")))
        #expect(issues.contains(.unexpectedColor(tileID: "g1")))
        #expect(issues.contains(.overlappingCells(Coordinate(4, 2), ids: ["d1", "o"])))
        #expect(!issues.contains(.startsSolved))
    }

    @Test func colorPairingAndLimits() {
        let lvl = level(5, 5,
            sources: [src("a", .orange, 0, 0, .east), src("b", .blue, 0, 1, .east), src("c", .green, 0, 2, .east),
                      src("d", .yellow, 0, 3, .east), src("e", .pink, 0, 4, .east)],
            receivers: [dst("x", .orange, 4, 0), dst("y", .blue, 4, 1), dst("z", .green, 4, 2), dst("w", .yellow, 4, 3)])
        let issues = validator.validate(lvl)
        #expect(issues.contains(.sourceWithoutReceiver(.pink)))
        #expect(issues.contains(.tooManyColors(5)))
        #expect(validator.validate(level(3, 3, sources: [])).contains(.noSources))
        let orphan = level(3, 3, sources: [src("a", .orange, 0, 0, .east)], receivers: [dst("x", .orange, 2, 0), dst("y", .blue, 2, 2)])
        #expect(validator.validate(orphan).contains(.receiverWithoutSource(.blue)))
    }

    @Test func rejectsLevelsThatStartSolved() {
        let lvl = level(3, 3, sources: [src("s1", .orange, 0, 0, .east)], receivers: [dst("d1", .orange, 2, 0)])
        #expect(validator.validate(lvl) == [.startsSolved])
    }

    @Test func deepChecksCompareRecordedParAndCount() {
        var lvl = valid
        lvl.par = 2
        lvl.solutionCount = nil
        #expect(validator.validate(lvl, deep: true) == [.parMismatch(recorded: 2, actual: 3), .solutionCountMismatch(recorded: nil, actual: 1)])

        let unsolvable = level(3, 3, sources: [src("s1", .orange, 0, 0, .east)], receivers: [dst("d1", .orange, 2, 2)])
        #expect(validator.validate(unsolvable, deep: true) == [.unsolvable, .solutionCountMismatch(recorded: nil, actual: 0)])
    }
}
