import Foundation
import Testing
@testable import GameCore

@Suite struct ColorRouterTests {
    let engine = SimulationEngine()

    @Test func turnsOnlyItsOwnColor() {
        let tiles = [colorRouter("c1", .orange, 2, 2, .south)]
        let orange = engine.simulate(level(5, 5, sources: [src("s1", .orange, 0, 2, .east)], receivers: [dst("d1", .orange, 2, 4)], tiles: tiles))
        #expect(orange.isSuccess)
        let blue = engine.simulate(level(5, 5, sources: [src("s1", .blue, 0, 2, .east)], receivers: [dst("d1", .blue, 4, 2)], tiles: tiles))
        #expect(blue.isSuccess)
        #expect(blue.trace[2].signals[0].direction == .east)
    }

    /// PLAN §1.1: renkli oklar sayesinde iki renk aynı hücreleri gerçekten paylaşır ve farklı çıkışlara gider.
    @Test func twoColorsShareTwoCellsAndDiverge() {
        let result = engine.simulate(level(7, 5,
            sources: [src("o", .orange, 3, 0, .south), src("b", .blue, 4, 2, .south)],
            receivers: [dst("do", .orange, 6, 4), dst("db", .blue, 0, 4)],
            tiles: [colorRouter("co", .orange, 3, 4, .east), colorRouter("cb", .blue, 4, 4, .west)]))
        #expect(result.isSuccess)
        #expect(result.deliveredSignalIDs == ["b", "o"])
        let visits = { (id: String) in Set(result.trace.flatMap { $0.signals.filter { $0.signalID == id }.map(\.coordinate) }) }
        #expect(visits("o").contains(Coordinate(4, 4)))
        #expect(visits("b").contains(Coordinate(3, 4)))
    }

    @Test func rotatesLikeARouter() {
        let tile = colorRouter("c1", .green, 0, 0, .north)
        #expect(LevelState.initial.rotating(tile).direction(of: tile) == .east)
    }
}

@Suite struct ToggleTests {
    let engine = SimulationEngine()

    func splitter(_ initial: Direction) -> (LevelDefinition, LevelState) {
        let lvl = level(5, 7,
            sources: [src("o", .orange, 0, 4, .east), src("b", .blue, 2, 0, .south)],
            receivers: [dst("do", .orange, 4, 4), dst("db", .blue, 2, 6)],
            tiles: [toggle("t1", 2, 4, .east)])
        return (lvl, LevelState.initial.setting(lvl.tiles[0], to: initial))
    }

    @Test func eachPassRotatesTheToggleClockwise() {
        let (lvl, state) = splitter(.east)
        let result = engine.simulate(lvl, state)
        #expect(result.isSuccess)
        #expect(result.trace[1].toggleDirections == ["t1": .east])
        #expect(result.trace[2].toggleDirections == ["t1": .south])
        #expect(result.trace[4].signals[1].direction == .south)
        #expect(result.trace[4].toggleDirections == ["t1": .west])
    }

    @Test func startingDirectionIsThePlayersChoice() {
        let (lvl, state) = splitter(.south)
        let result = engine.simulate(lvl, state)
        #expect(state.moves == 1)
        #expect(result.failures == [SignalFailure(signalID: "o", reason: .wrongReceiver, coordinate: Coordinate(2, 6), tick: 4)])
    }

    @Test func everyRunStartsFromTheInitialDirection() {
        let (lvl, state) = splitter(.east)
        #expect(engine.simulate(lvl, state) == engine.simulate(lvl, state))
    }

    /// Makas yüzünden aynı (hücre, yön) tekrar edebilir ama sinyal yine de çıkabilir: döngü sayılmamalı.
    @Test func revisitingACellIsNotALoopWhenTheToggleChanged() {
        let result = engine.simulate(level(4, 3,
            sources: [src("s1", .orange, 0, 1, .east)],
            receivers: [dst("d1", .orange, 1, 2)],
            tiles: [toggle("t", 1, 1, .north), router("a", 1, 0, .east), router("b", 2, 0, .south), router("c", 2, 1, .west)]))
        #expect(result.isSuccess)
        #expect(result.totalTicks == 8)
    }

    /// Tick 9 = tick 1 ile aynı tahta durumu: sinyal (1,2)'de doğuya bakıyor, makas kuzeyde.
    @Test func wholeBoardRepetitionIsALoop() {
        let result = engine.simulate(level(5, 5,
            sources: [src("s1", .orange, 0, 2, .east)],
            tiles: [toggle("t", 2, 2, .north), router("n", 2, 1, .south), router("e", 3, 2, .west), router("s", 2, 3, .north), router("w", 1, 2, .east)]))
        #expect(result.failures == [SignalFailure(signalID: "s1", reason: .loop, coordinate: Coordinate(1, 2), tick: 9)])
    }
}

@Suite struct BridgeTests {
    let engine = SimulationEngine()

    @Test func perpendicularCrossingOnTheSameTickIsAllowed() {
        let crossing = level(3, 3,
            sources: [src("s1", .orange, 0, 1, .east), src("s2", .blue, 1, 0, .south)],
            receivers: [dst("d1", .orange, 2, 1), dst("d2", .blue, 1, 2)])
        #expect(engine.simulate(crossing).failures.map(\.reason) == [.collision, .collision])

        var bridged = crossing
        bridged.tiles = [bridge("g", 1, 1)]
        let result = engine.simulate(bridged)
        #expect(result.isSuccess)
        #expect(result.totalTicks == 2)
    }

    @Test func sameAxisSignalsStillCollideOnABridge() {
        let result = engine.simulate(level(5, 1,
            sources: [src("s1", .orange, 0, 0, .east), src("s2", .blue, 4, 0, .west)],
            tiles: [bridge("g", 2, 0)]))
        #expect(result.failures.map(\.reason) == [.collision, .collision])
        #expect(result.failures[0].coordinate == Coordinate(2, 0))
    }

    @Test func bridgeDoesNotTurnSignals() {
        let result = engine.simulate(level(3, 1, sources: [src("s1", .orange, 0, 0, .east)], receivers: [dst("d1", .orange, 2, 0)], tiles: [bridge("g", 1, 0)]))
        #expect(result.isSuccess)
    }
}

@Suite struct SpecialTileCodingTests {
    @Test func decodesNewKinds() throws {
        let json = """
            [{"id": "c1", "kind": "colorRouter", "color": "blue", "x": 3, "y": 3, "dir": "north", "rotatable": true},
             {"id": "t1", "kind": "toggle", "x": 1, "y": 1, "dir": "west", "rotatable": true},
             {"id": "g1", "kind": "bridge", "x": 2, "y": 2}]
            """
        let tiles = try JSONDecoder().decode([Tile].self, from: Data(json.utf8))
        #expect(tiles == [colorRouter("c1", .blue, 3, 3, .north), toggle("t1", 1, 1, .west), bridge("g1", 2, 2)])
        #expect(try JSONDecoder().decode([Tile].self, from: JSONEncoder().encode(tiles)) == tiles)
    }
}
