/// Seviyeleri gerçek oyuncu gibi `PlaySession` üzerinden oynayan bot (PLAN §7). Test ve içerik kontrolü içindir.
public struct BotPlayer: Sendable {
    public enum Strategy: Sendable {
        /// Kayıtlı en iyi çözüme tek tek dokunuşlarla gider, sonra çalıştırır.
        case bestSolution
        /// Hiç düşünmez: çalıştırır, olmazsa ipucu alır, tekrar çalıştırır.
        case hintsOnly
    }

    public init() {}

    public func play(_ level: LevelDefinition, strategy: Strategy) -> PlaySession {
        var session = PlaySession(level: level)
        switch strategy {
        case .bestSolution:
            guard let target = level.solutions?.first ?? Solver().solve(level).solutions.first else { return session }
            for tile in level.tiles {
                guard let wanted = target.directions[tile.id], let current = session.state.direction(of: tile) else { continue }
                for _ in 0..<wanted.clockwiseSteps(from: current) { session.rotate(tile.id) }
            }
            session.run()
        case .hintsOnly:
            for _ in 0...level.tiles.count {
                if session.run().isSuccess { break }
                if session.takeHint() == nil { break }
            }
        }
        return session
    }
}
