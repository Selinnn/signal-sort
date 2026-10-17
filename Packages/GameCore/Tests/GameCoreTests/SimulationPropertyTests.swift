import Testing
@testable import GameCore

/// Rastgele tahtalarda motorun genel sözleşmesi: deterministik, her zaman sınırlı sürede biter, sonuç tutarlı.
@Suite struct SimulationPropertyTests {
    @Test func randomBoardsAreDeterministicAndTerminate() {
        var rng = TestRNG(seed: 0x5167_4E41_4C53)
        let engine = SimulationEngine()
        for _ in 0..<1_000 {
            let (lvl, state) = randomBoard(&rng)
            let first = engine.simulate(lvl, state)
            let second = engine.simulate(lvl, state)
            #expect(first == second)
            #expect(first.totalTicks < SimulationEngine.tickLimit(level: lvl, toggleCount: lvl.tiles.filter { $0.kind == .toggle }.count))
            #expect(first.trace.map(\.tick) == Array(0...first.totalTicks))
            if first.isSuccess {
                #expect(first.failures.isEmpty)
                #expect(Set(first.deliveredSignalIDs) == Set(lvl.sources.map(\.id)))
            } else {
                #expect(!first.failures.isEmpty)
                #expect(first.failures.allSatisfy { $0.tick == first.totalTicks })
            }
        }
    }

    private func randomBoard(_ rng: inout TestRNG) -> (LevelDefinition, LevelState) {
        let width = Int.random(in: 3...7, using: &rng)
        let height = Int.random(in: 3...7, using: &rng)
        var cells = (0..<width).flatMap { x in (0..<height).map { Coordinate(x, $0) } }
        cells.shuffle(using: &rng)
        var next = cells.makeIterator()
        let colors = SignalColor.allCases

        let signalCount = Int.random(in: 1...4, using: &rng)
        var sources: [Source] = []
        var receivers: [Receiver] = []
        for i in 0..<signalCount {
            let color = colors[i % 3]
            sources.append(Source(id: "s\(i)", color: color, at: next.next()!, direction: Direction.allCases.randomElement(using: &rng)!))
            receivers.append(Receiver(id: "d\(i)", color: color, at: next.next()!))
        }
        var tiles: [Tile] = []
        let tileCount = Int.random(in: 0...(cells.count - 2 * signalCount), using: &rng)
        for i in 0..<tileCount {
            let cell = next.next()!
            let direction = Direction.allCases.randomElement(using: &rng)!
            let rotatable = Bool.random(using: &rng)
            switch Int.random(in: 0..<10, using: &rng) {
            case 0: tiles.append(.blocker("b\(i)", at: cell))
            case 1: tiles.append(.bridge("g\(i)", at: cell))
            case 2: tiles.append(.colorRouter("c\(i)", colors[Int.random(in: 0..<3, using: &rng)], at: cell, direction, rotatable: rotatable))
            case 3 where tiles.filter({ $0.kind == .toggle }).count < 3: tiles.append(.toggle("t\(i)", at: cell, direction, rotatable: rotatable))
            default: tiles.append(.router("r\(i)", at: cell, direction, rotatable: rotatable))
            }
        }
        var rotations: [String: Int] = [:]
        for tile in tiles where tile.rotatable { rotations[tile.id] = Int.random(in: 0...3, using: &rng) }
        let lvl = LevelDefinition(id: "random", width: width, height: height, sources: sources, receivers: receivers, tiles: tiles)
        return (lvl, LevelState(rotations: rotations))
    }
}
