import Testing
@testable import GameCore

@Suite struct SolverTests {
    let solver = Solver()

    @Test func schemaExampleHasOneSolutionWithParThree() {
        let report = solver.solve(Fixtures.schemaExample)
        #expect(report.isExhaustive)
        #expect(report.par == 3)
        #expect(report.solutions == [Solution(directions: ["r1": .east], moves: 3)])
    }

    @Test func countsOnlyMeaningfulDecisions() {
        let report = solver.solve(Fixtures.twoRoutes)
        #expect(report.solutionCount == 2)
        #expect(report.par == 4)
        #expect(report.solutions[0].directions == ["r1": .south, "r3": .east, "r4": .south])
        #expect(report.solutions[1].directions == ["r1": .east, "r2": .south, "r4": .south])
        #expect(report.solutions.allSatisfy { $0.directions["decoy"] == nil })
    }

    @Test func everyReportedSolutionActuallySolves() {
        for lvl in [Fixtures.schemaExample, Fixtures.twoRoutes] {
            for solution in solver.solve(lvl).solutions {
                let state = solution.state(in: lvl)
                #expect(SimulationEngine().simulate(lvl, state).isSuccess)
                #expect(state.moves == solution.moves)
            }
        }
    }

    @Test func otherColorsDoNotBranchOnColorRouters() {
        let lvl = level(5, 3,
            sources: [src("s1", .blue, 0, 1, .east)],
            receivers: [dst("d1", .blue, 4, 1)],
            tiles: [colorRouter("c1", .orange, 2, 1, .north)])
        let report = solver.solve(lvl)
        #expect(report.solutions == [Solution(directions: [:], moves: 0)])
        #expect(report.searchNodes == 1)
    }

    @Test func togglesBranchOnTheirStartingDirection() {
        let lvl = level(5, 7,
            sources: [src("o", .orange, 0, 4, .east), src("b", .blue, 2, 0, .south)],
            receivers: [dst("do", .orange, 4, 4), dst("db", .blue, 2, 6)],
            tiles: [toggle("t1", 2, 4, .west)])
        let report = solver.solve(lvl)
        #expect(report.solutions == [Solution(directions: ["t1": .east], moves: 2)])
    }

    @Test func unsolvableLevelHasNoPar() {
        let report = solver.solve(level(3, 1, sources: [src("s1", .orange, 0, 0, .east)], receivers: [dst("d1", .blue, 2, 0)]))
        #expect(!report.isSolvable)
        #expect(report.par == nil)
        #expect(report.isExhaustive)
    }

    @Test func budgetsStopTheSearch() {
        let report = Solver(maxSolutions: 1).solve(Fixtures.twoRoutes)
        #expect(report.solutionCount == 1)
        #expect(!report.isExhaustive)
        #expect(!Solver(maxNodes: 1).solve(Fixtures.twoRoutes).isExhaustive)
    }

    /// Solver her çözülebilir durumu bulmalı: rastgele tahtalarda tüm dönüş kombinasyonlarıyla karşılaştırılır.
    @Test func matchesBruteForceOnSmallRandomBoards() {
        var rng = TestRNG(seed: 42)
        let engine = SimulationEngine()
        for _ in 0..<200 {
            let lvl = randomSmallBoard(&rng)
            let rotatable = lvl.tiles.filter(\.rotatable)
            var bruteForceMin: Int?
            for combo in 0..<(1 << (2 * rotatable.count)) {
                var state = LevelState.initial
                for (n, tile) in rotatable.enumerated() {
                    state = LevelState(rotations: state.rotations.merging([tile.id: (combo >> (2 * n)) & 3]) { $1 })
                }
                if engine.simulate(lvl, state).isSuccess { bruteForceMin = min(bruteForceMin ?? .max, state.moves) }
            }
            #expect(solver.solve(lvl).par == bruteForceMin)
        }
    }

    private func randomSmallBoard(_ rng: inout TestRNG) -> LevelDefinition {
        var cells = (0..<4).flatMap { x in (0..<4).map { Coordinate(x, $0) } }
        cells.shuffle(using: &rng)
        var next = cells.makeIterator()
        let colors: [SignalColor] = [.orange, .blue]
        let signals = Int.random(in: 1...2, using: &rng)
        var sources: [Source] = []
        var receivers: [Receiver] = []
        for i in 0..<signals {
            sources.append(Source(id: "s\(i)", color: colors[i], at: next.next()!, direction: Direction.allCases.randomElement(using: &rng)!))
            receivers.append(Receiver(id: "d\(i)", color: colors[i], at: next.next()!))
        }
        var tiles: [Tile] = []
        for i in 0..<Int.random(in: 2...5, using: &rng) {
            let cell = next.next()!
            let direction = Direction.allCases.randomElement(using: &rng)!
            switch Int.random(in: 0..<6, using: &rng) {
            case 0: tiles.append(.toggle("t\(i)", at: cell, direction))
            case 1: tiles.append(.colorRouter("c\(i)", colors[Int.random(in: 0..<signals, using: &rng)], at: cell, direction))
            case 2: tiles.append(.blocker("b\(i)", at: cell))
            default: tiles.append(.router("r\(i)", at: cell, direction))
            }
        }
        return LevelDefinition(id: "rnd", width: 4, height: 4, sources: sources, receivers: receivers, tiles: tiles)
    }
}

@Suite struct ScoringTests {
    @Test(arguments: [(3, 3, false, 3), (4, 3, false, 2), (5, 3, false, 2), (6, 3, false, 1), (2, 3, false, 3),
                      (3, 3, true, 2), (6, 3, true, 1), (0, 0, false, 3)])
    func stars(moves: Int, par: Int, hintUsed: Bool, expected: Int) {
        #expect(Scoring.stars(moves: moves, par: par, hintUsed: hintUsed) == expected)
    }
}

@Suite struct HintProviderTests {
    let provider = HintProvider()

    func hint(_ lvl: LevelDefinition, _ state: LevelState) -> Hint? {
        provider.hint(lvl, state, solutions: Solver().solve(lvl).solutions)
    }

    @Test func pointsAtTheWrongTile() {
        #expect(hint(Fixtures.schemaExample, .initial) == Hint(tileID: "r1", currentDirection: .south, targetDirection: .east, remainingWrongTiles: 0))
    }

    @Test func noHintWhenAlreadySolved() {
        let lvl = Fixtures.schemaExample
        #expect(hint(lvl, LevelState.initial.setting(lvl.tiles[0], to: .east)) == nil)
    }

    @Test func noHintWhenUnsolvable() {
        let lvl = level(3, 1, sources: [src("s1", .orange, 0, 0, .east)], receivers: [dst("d1", .blue, 2, 0)])
        #expect(hint(lvl, .initial) == nil)
    }

    @Test func followsTheSolutionClosestToThePlayersBoard() {
        let lvl = Fixtures.twoRoutes
        let tiles = Dictionary(uniqueKeysWithValues: lvl.tiles.map { ($0.id, $0) })
        // r1 güneyde: B çözümüne 1 taş uzak → r4.
        let towardB = LevelState.initial.setting(tiles["r1"]!, to: .south)
        #expect(hint(lvl, towardB)?.tileID == "r4")
        // r1 doğuda ve r2 güneyde: A çözümüne 1 taş uzak → r4.
        let towardA = LevelState.initial.setting(tiles["r1"]!, to: .east).setting(tiles["r2"]!, to: .south)
        #expect(hint(lvl, towardA) == Hint(tileID: "r4", currentDirection: .north, targetDirection: .south, remainingWrongTiles: 0))
        // r1 doğuda: A'ya 2, B'ye 2 taş uzak; eşitlikte az hamleli B seçilir ve sinyalin ilk girdiği r1 gösterilir.
        let tied = LevelState.initial.setting(tiles["r1"]!, to: .east)
        #expect(hint(lvl, tied) == Hint(tileID: "r1", currentDirection: .east, targetDirection: .south, remainingWrongTiles: 1))
    }

    @Test func applyingHintsRepeatedlySolvesTheLevel() {
        for lvl in [Fixtures.schemaExample, Fixtures.twoRoutes] {
            let solutions = Solver().solve(lvl).solutions
            var state = LevelState.initial
            for _ in 0..<lvl.tiles.count {
                guard let h = provider.hint(lvl, state, solutions: solutions) else { break }
                state = state.setting(lvl.tile(withID: h.tileID)!, to: h.targetDirection)
            }
            #expect(SimulationEngine().simulate(lvl, state).isSuccess)
        }
    }
}
