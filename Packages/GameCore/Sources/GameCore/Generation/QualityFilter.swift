/// Bir seviyenin par çözümü üzerinden ölçülen yapısal metrikleri.
public struct LevelMetrics: Codable, Hashable, Sendable {
    public var signals: Int
    public var par: Int
    public var solutionCount: Int
    public var searchNodes: Int
    /// Par çözümünde sinyallerin girdiği dönebilir taşlar.
    public var decisions: Int
    /// Başlangıçta yanlış yönde olan par çözümü taşları.
    public var scrambled: Int
    /// En az iki farklı sinyalin uğradığı hücreler.
    public var sharedCells: Int
    public var colorRouterShares: Int
    public var toggleMultiEntries: Int
    public var bridgeCrossings: Int
    /// Par çözümünde hiç uğranmayan dönebilir taşlar.
    public var decoys: Int
    public var blockers: Int

    public static func measure(_ level: LevelDefinition, report: SolveReport) -> LevelMetrics? {
        guard let best = report.solutions.first, let par = report.par else { return nil }
        let result = SimulationEngine().simulate(level, best.state(in: level))
        let colors = Dictionary(uniqueKeysWithValues: level.sources.map { ($0.id, $0.color) })

        // Hücre → (sinyal, giriş tick'i). Tick 0 kaynaklardır, sayılmaz.
        var visitors: [Coordinate: Set<String>] = [:]
        var entries: [Coordinate: Int] = [:]
        for snapshot in result.trace.dropFirst() {
            let previous = result.trace[snapshot.tick - 1]
            for (index, signal) in snapshot.signals.enumerated() where previous.signals[index].coordinate != signal.coordinate {
                visitors[signal.coordinate, default: []].insert(signal.signalID)
                entries[signal.coordinate, default: 0] += 1
            }
        }

        var metrics = LevelMetrics(
            signals: level.sources.count, par: par, solutionCount: report.solutionCount, searchNodes: report.searchNodes,
            decisions: 0, scrambled: 0, sharedCells: visitors.values.filter { $0.count > 1 }.count,
            colorRouterShares: 0, toggleMultiEntries: 0, bridgeCrossings: 0, decoys: 0,
            blockers: level.tiles.filter { $0.kind == .blocker }.count)
        for tile in level.tiles {
            let ids = visitors[tile.coordinate] ?? []
            if tile.rotatable && tile.kind.isDirectional {
                if let required = best.directions[tile.id] {
                    metrics.decisions += 1
                    if required != tile.direction { metrics.scrambled += 1 }
                } else if ids.isEmpty {
                    metrics.decoys += 1
                }
            }
            switch tile.kind {
            case .colorRouter:
                let tileColors = ids.compactMap { colors[$0] }
                if tileColors.contains(where: { $0 == tile.color }) && tileColors.contains(where: { $0 != tile.color }) {
                    metrics.colorRouterShares += 1
                }
            case .toggle where (entries[tile.coordinate] ?? 0) >= 2:
                metrics.toggleMultiEntries += 1
            case .bridge where ids.count >= 2:
                metrics.bridgeCrossings += 1
            default:
                break
            }
        }
        return metrics
    }
}

public enum QualityRejection: String, Codable, CaseIterable, Sendable {
    case constructionFailed
    case startsSolved
    case unsolvable
    case searchTooLarge
    case tooManySolutions
    case parOutOfBand
    case searchNodesOutOfBand
    case tooFewDecisions
    case tooFewScrambled
    case tooFewSharedCells
    case missingColorRouterShare
    case missingToggleMultiEntry
    case missingBridgeCrossing
}

/// Üretilen adayın profile uygunluğunu denetler (PLAN §6.3). Benzerlik kontrolü toplu üretimde yapılır.
public struct QualityFilter: Sendable {
    public init() {}

    public func evaluate(_ metrics: LevelMetrics, profile: DifficultyProfile) -> [QualityRejection] {
        var rejections: [QualityRejection] = []
        if metrics.solutionCount > profile.maxSolutions { rejections.append(.tooManySolutions) }
        if !profile.par.contains(metrics.par) { rejections.append(.parOutOfBand) }
        if !profile.searchNodes.contains(metrics.searchNodes) { rejections.append(.searchNodesOutOfBand) }
        if metrics.decisions < profile.minDecisions { rejections.append(.tooFewDecisions) }
        if metrics.scrambled < profile.minScrambled { rejections.append(.tooFewScrambled) }
        if metrics.sharedCells < profile.minSharedCells { rejections.append(.tooFewSharedCells) }
        for requirement in profile.requirements {
            switch requirement {
            case .colorRouterShare where metrics.colorRouterShares == 0: rejections.append(.missingColorRouterShare)
            case .toggleMultiEntry where metrics.toggleMultiEntries == 0: rejections.append(.missingToggleMultiEntry)
            case .bridgeCrossing where metrics.bridgeCrossings == 0: rejections.append(.missingBridgeCrossing)
            default: break
            }
        }
        return rejections
    }
}
