import Foundation
import Testing
@testable import GameCore

@Suite struct DirectionTests {
    @Test func clockwiseRotationCycles() {
        #expect(Direction.north.clockwise == .east)
        #expect(Direction.west.clockwise == .north)
        #expect(Direction.south.rotated(by: 4) == .south)
        #expect(Direction.north.rotated(by: -1) == .west)
        #expect(Direction.east.opposite == .west)
    }

    @Test func deltasUseYDownCoordinates() {
        #expect(Coordinate(2, 2).moved(.north) == Coordinate(2, 1))
        #expect(Coordinate(2, 2).moved(.south) == Coordinate(2, 3))
        #expect(Coordinate(2, 2).moved(.east) == Coordinate(3, 2))
        #expect(Coordinate(2, 2).moved(.west) == Coordinate(1, 2))
    }

    @Test(arguments: Direction.allCases, Direction.allCases)
    func clockwiseStepsInvertsRotation(from: Direction, to: Direction) {
        let steps = to.clockwiseSteps(from: from)
        #expect((0...3).contains(steps))
        #expect(from.rotated(by: steps) == to)
    }
}

@Suite struct LevelStateTests {
    let rotatable = router("r1", 0, 0, .south)
    let fixed = router("r2", 1, 0, .east, rotatable: false)

    @Test func movesAreDerivedFromBoardNotTapHistory() {
        var state = LevelState.initial
        for _ in 0..<3 { state = state.rotating(rotatable) }
        #expect(state.moves == 3)
        #expect(state.direction(of: rotatable) == .east)
        state = state.rotating(rotatable)
        #expect(state.moves == 0)
        #expect(state == .initial)
    }

    @Test func fixedRoutersIgnoreRotation() {
        #expect(LevelState.initial.rotating(fixed) == .initial)
        #expect(LevelState.initial.setting(fixed, to: .north) == .initial)
        #expect(LevelState(rotations: ["r2": 2]).direction(of: fixed) == .east)
    }

    @Test func settingDirectionStoresClockwiseSteps() {
        let state = LevelState.initial.setting(rotatable, to: .north)
        #expect(state.rotation(of: "r1") == 2)
        #expect(state.direction(of: rotatable) == .north)
        #expect(LevelState.initial.setting(rotatable, to: .south) == .initial)
    }

    @Test func rotationsAreNormalized() {
        #expect(LevelState(rotations: ["a": 5, "b": 4, "c": -1]) == LevelState(rotations: ["a": 1, "c": 3]))
    }
}

@Suite struct LevelCodingTests {
    let json = """
        { "id": "c007", "schemaVersion": 1, "width": 5, "height": 5,
          "sources":   [{"id": "s1", "color": "orange", "x": 0, "y": 2, "dir": "east"}],
          "receivers": [{"id": "d1", "color": "orange", "x": 4, "y": 2}],
          "tiles": [
            {"id": "r1", "kind": "router",  "x": 1, "y": 2, "dir": "south", "rotatable": true},
            {"id": "r2", "kind": "router",  "x": 2, "y": 2, "dir": "east"},
            {"id": "b1", "kind": "blocker", "x": 3, "y": 1}
          ],
          "par": 3, "solutionCount": 1, "seed": null }
        """

    @Test func decodesSchemaExample() throws {
        let level = try JSONDecoder().decode(LevelDefinition.self, from: Data(json.utf8))
        #expect(level.sources == [src("s1", .orange, 0, 2, .east)])
        #expect(level.receivers == [dst("d1", .orange, 4, 2)])
        #expect(level.tiles == [router("r1", 1, 2, .south), router("r2", 2, 2, .east, rotatable: false), blocker("b1", 3, 1)])
        #expect(level.par == 3)
        #expect(level.seed == nil)
    }

    @Test func roundTrips() throws {
        let level = try JSONDecoder().decode(LevelDefinition.self, from: Data(json.utf8))
        let again = try JSONDecoder().decode(LevelDefinition.self, from: JSONEncoder().encode(level))
        #expect(again == level)
    }

    @Test func rejectsUnknownEnumValues() {
        let bad = json.replacingOccurrences(of: "\"east\"}]", with: "\"up\"}]")
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LevelDefinition.self, from: Data(bad.utf8))
        }
    }
}
