public struct Hint: Hashable, Sendable {
    public var tileID: String
    public var currentDirection: Direction
    public var targetDirection: Direction
    /// İpucu uygulandıktan sonra hedef çözüme göre hâlâ yanlış olan taş sayısı.
    public var remainingWrongTiles: Int
}

/// Mevcut tahtaya en yakın çözümü seçer ve yanlış yöndeki bir taşı (sinyallerin ilk karşılaştığını) gösterir.
/// Yakınlık: çözümün gerektirdiği taşlardan kaçının şu an farklı yönde olduğu. Eşitlikte az hamleli çözüm.
public struct HintProvider: Sendable {
    public init() {}

    public func hint(_ level: LevelDefinition, _ state: LevelState, solutions: [Solution]) -> Hint? {
        let engine = SimulationEngine()
        if engine.simulate(level, state).isSuccess { return nil }

        let tilesByID = Dictionary(uniqueKeysWithValues: level.tiles.map { ($0.id, $0) })
        func wrongTiles(_ solution: Solution) -> [String] {
            solution.directions.keys.sorted().filter { id in
                state.direction(of: tilesByID[id]!) != solution.directions[id]
            }
        }
        // `solutions` zaten hamleye göre sıralı; `min` eşitlikte ilkini korur.
        guard let target = solutions.min(by: { wrongTiles($0).count < wrongTiles($1).count }) else { return nil }
        let wrong = wrongTiles(target)
        guard !wrong.isEmpty else { return nil }

        // Hedef çözümde sinyallerin ilk girdiği yanlış taş en anlaşılır ipucudur.
        let trace = engine.simulate(level, target.state(in: level)).trace
        var firstEntry: [Coordinate: Int] = [:]
        for snapshot in trace {
            for signal in snapshot.signals where firstEntry[signal.coordinate] == nil {
                firstEntry[signal.coordinate] = snapshot.tick
            }
        }
        let chosen = wrong.min { a, b in
            let ta = firstEntry[tilesByID[a]!.coordinate] ?? .max
            let tb = firstEntry[tilesByID[b]!.coordinate] ?? .max
            return ta != tb ? ta < tb : a < b
        }!
        let tile = tilesByID[chosen]!
        return Hint(
            tileID: chosen,
            currentDirection: state.direction(of: tile)!,
            targetDirection: target.directions[chosen]!,
            remainingWrongTiles: wrong.count - 1)
    }
}
