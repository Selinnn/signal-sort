/// Bir çözüm: yalnız sinyallerin gerçekten girdiği dönebilir taşların yönleri. Diğer taşlar başlangıç yönünde kalır.
public struct Solution: Codable, Hashable, Sendable {
    public var directions: [String: Direction]
    /// Bu çözümün başlangıç durumuna uzaklığı (saat yönü adım toplamı).
    public var moves: Int

    public func state(in level: LevelDefinition) -> LevelState {
        var state = LevelState.initial
        for tile in level.tiles {
            if let direction = directions[tile.id] { state = state.setting(tile, to: direction) }
        }
        return state
    }
}

public struct SolveReport: Sendable {
    /// En az hamleli çözümün hamlesi; çözüm yoksa nil.
    public var par: Int? { solutions.first?.moves }
    /// Hamleye, sonra deterministik anahtara göre sıralı. `isExhaustive` false ise eksik olabilir.
    public var solutions: [Solution]
    public var solutionCount: Int { solutions.count }
    /// Simülasyon çağrısı sayısı. Zorluk ölçütü olarak kullanılır (PLAN §1.4).
    public var searchNodes: Int
    /// Arama bütçe veya çözüm sınırına takılmadan tamamlandı mı.
    public var isExhaustive: Bool
    public var isSolvable: Bool { !solutions.isEmpty }
}

/// Olay güdümlü solver (PLAN §1.4). Sinyaller simüle edilir; bir sinyal yönü henüz seçilmemiş bir dönebilir
/// taşa girdiğinde 4 yöne dallanılır. Hiçbir sinyalin uğramadığı taşlar başlangıç yönünde kalır, böylece
/// tuzak taşlar çözüm sayısını şişirmez.
public struct Solver: Sendable {
    public var maxSolutions: Int
    public var maxNodes: Int

    public init(maxSolutions: Int = 1_000, maxNodes: Int = 500_000) {
        self.maxSolutions = maxSolutions
        self.maxNodes = maxNodes
    }

    public func solve(_ level: LevelDefinition) -> SolveReport {
        let engine = SimulationEngine()
        let decisionTiles = level.tiles.filter { $0.rotatable && $0.kind.isDirectional }
        let tilesByID = Dictionary(uniqueKeysWithValues: decisionTiles.map { ($0.id, $0) })
        let allUndecided = Set(tilesByID.keys)

        var solutions: [Solution] = []
        var nodes = 0
        var exhaustive = true
        // Açık uçlu DFS; yığın deterministik sırayla işlenir.
        var stack: [[String: Direction]] = [[:]]

        while let assignment = stack.popLast() {
            if nodes >= maxNodes || solutions.count >= maxSolutions {
                exhaustive = false
                break
            }
            nodes += 1
            var state = LevelState.initial
            for (id, direction) in assignment { state = state.setting(tilesByID[id]!, to: direction) }
            let undecided = allUndecided.subtracting(assignment.keys)

            switch engine.run(level, state, undecided: undecided) {
            case .finished(let result):
                if result.isSuccess {
                    solutions.append(Solution(directions: assignment, moves: state.moves))
                }
            case .decisionNeeded(let tileID):
                for direction in Direction.allCases.reversed() {
                    var next = assignment
                    next[tileID] = direction
                    stack.append(next)
                }
            }
        }

        solutions.sort { lhs, rhs in
            if lhs.moves != rhs.moves { return lhs.moves < rhs.moves }
            return Self.sortKey(lhs) < Self.sortKey(rhs)
        }
        return SolveReport(solutions: solutions, searchNodes: nodes, isExhaustive: exhaustive)
    }

    private static func sortKey(_ solution: Solution) -> String {
        solution.directions.keys.sorted().map { "\($0)=\(solution.directions[$0]!.rawValue)" }.joined(separator: ",")
    }
}
