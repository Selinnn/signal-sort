public enum ValidationIssue: Hashable, Sendable, CustomStringConvertible {
    case unsupportedSchemaVersion(Int)
    case invalidSize(width: Int, height: Int)
    case noSources
    case duplicateID(String)
    case outOfBounds(id: String)
    case overlappingCells(Coordinate, ids: [String])
    case missingDirection(tileID: String)
    case unexpectedDirection(tileID: String)
    case missingColor(tileID: String)
    case unexpectedColor(tileID: String)
    case notRotatable(tileID: String)
    case sourceWithoutReceiver(SignalColor)
    case receiverWithoutSource(SignalColor)
    case tooManyColors(Int)
    case colorRouterColorNotInLevel(tileID: String)
    case startsSolved
    case unsolvable
    case parMismatch(recorded: Int?, actual: Int?)
    case solutionCountMismatch(recorded: Int?, actual: Int)
    case solutionsMismatch
    case searchIncomplete

    public var description: String {
        switch self {
        case .unsupportedSchemaVersion(let v): "Desteklenmeyen şema sürümü \(v)"
        case .invalidSize(let w, let h): "Geçersiz tahta boyutu \(w)×\(h) (\(LevelValidator.sizeRange) arası olmalı)"
        case .noSources: "Seviyede kaynak yok"
        case .duplicateID(let id): "Tekrarlanan ID: \(id)"
        case .outOfBounds(let id): "\(id) tahta dışında"
        case .overlappingCells(let c, let ids): "\(c) hücresinde birden fazla öğe: \(ids.joined(separator: ", "))"
        case .missingDirection(let id): "\(id) yönlü bir taş ama yönü yok"
        case .unexpectedDirection(let id): "\(id) yönsüz bir taş ama yönü var"
        case .missingColor(let id): "\(id) renkli ok ama rengi yok"
        case .unexpectedColor(let id): "\(id) renkli ok değil ama rengi var"
        case .notRotatable(let id): "\(id) yönsüz olduğu için döndürülemez"
        case .sourceWithoutReceiver(let c): "\(c.rawValue) kaynağının çıkışı yok"
        case .receiverWithoutSource(let c): "\(c.rawValue) çıkışının kaynağı yok"
        case .tooManyColors(let n): "\(n) renk var, en fazla \(LevelValidator.maxColors)"
        case .colorRouterColorNotInLevel(let id): "\(id) seviyede olmayan bir rengi çeviriyor"
        case .startsSolved: "Başlangıç durumu zaten çözülmüş"
        case .unsolvable: "Çözümü yok"
        case .parMismatch(let r, let a): "Kayıtlı par \(r.map(String.init) ?? "yok"), solver par \(a.map(String.init) ?? "yok")"
        case .solutionCountMismatch(let r, let a): "Kayıtlı çözüm sayısı \(r.map(String.init) ?? "yok"), solver \(a)"
        case .solutionsMismatch: "Kayıtlı çözüm listesi solver ile uyuşmuyor"
        case .searchIncomplete: "Solver arama bütçesini aştı; par ve çözüm sayısı kesin değil"
        }
    }
}

/// Seviye doğrulama. Yapısal kontroller her zaman; `deep` ile solver çalıştırılır ve par/çözüm sayısı kontrol edilir.
public struct LevelValidator: Sendable {
    public static let sizeRange = 3...7
    public static let maxColors = 4

    public var solver: Solver

    public init(solver: Solver = Solver()) {
        self.solver = solver
    }

    public func validate(_ level: LevelDefinition, deep: Bool = false) -> [ValidationIssue] {
        var issues = structuralIssues(level)
        // Yapısı bozuk seviyede simülasyon anlamsız.
        guard issues.isEmpty else { return issues }

        if SimulationEngine().simulate(level).isSuccess { issues.append(.startsSolved) }
        guard deep else { return issues }

        let report = solver.solve(level)
        if !report.isExhaustive { issues.append(.searchIncomplete) }
        if !report.isSolvable { issues.append(.unsolvable) }
        if level.par != report.par { issues.append(.parMismatch(recorded: level.par, actual: report.par)) }
        if level.solutionCount != report.solutionCount {
            issues.append(.solutionCountMismatch(recorded: level.solutionCount, actual: report.solutionCount))
        }
        if let recorded = level.solutions, recorded != report.solutions { issues.append(.solutionsMismatch) }
        return issues
    }

    private func structuralIssues(_ level: LevelDefinition) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if level.schemaVersion != GameCore.schemaVersion { issues.append(.unsupportedSchemaVersion(level.schemaVersion)) }
        if !Self.sizeRange.contains(level.width) || !Self.sizeRange.contains(level.height) {
            issues.append(.invalidSize(width: level.width, height: level.height))
        }
        if level.sources.isEmpty { issues.append(.noSources) }

        let placed: [(id: String, coordinate: Coordinate)] =
            level.sources.map { ($0.id, $0.coordinate) } + level.receivers.map { ($0.id, $0.coordinate) } + level.tiles.map { ($0.id, $0.coordinate) }

        var seenIDs: Set<String> = []
        for item in placed where !seenIDs.insert(item.id).inserted { issues.append(.duplicateID(item.id)) }
        for item in placed where !level.contains(item.coordinate) { issues.append(.outOfBounds(id: item.id)) }

        let byCell = Dictionary(grouping: placed, by: \.coordinate)
        for cell in byCell.keys.sorted(by: { ($0.y, $0.x) < ($1.y, $1.x) }) where byCell[cell]!.count > 1 {
            issues.append(.overlappingCells(cell, ids: byCell[cell]!.map(\.id)))
        }

        let levelColors = Set(level.sources.map(\.color)).union(level.receivers.map(\.color))
        for tile in level.tiles {
            if tile.kind.isDirectional && tile.direction == nil { issues.append(.missingDirection(tileID: tile.id)) }
            if !tile.kind.isDirectional && tile.direction != nil { issues.append(.unexpectedDirection(tileID: tile.id)) }
            if !tile.kind.isDirectional && tile.rotatable { issues.append(.notRotatable(tileID: tile.id)) }
            if tile.kind == .colorRouter {
                if let color = tile.color {
                    if !levelColors.contains(color) { issues.append(.colorRouterColorNotInLevel(tileID: tile.id)) }
                } else {
                    issues.append(.missingColor(tileID: tile.id))
                }
            } else if tile.color != nil {
                issues.append(.unexpectedColor(tileID: tile.id))
            }
        }

        let sourceColors = Set(level.sources.map(\.color))
        let receiverColors = Set(level.receivers.map(\.color))
        for color in SignalColor.allCases {
            if sourceColors.contains(color) && !receiverColors.contains(color) { issues.append(.sourceWithoutReceiver(color)) }
            if receiverColors.contains(color) && !sourceColors.contains(color) { issues.append(.receiverWithoutSource(color)) }
        }
        if levelColors.count > Self.maxColors { issues.append(.tooManyColors(levelColors.count)) }
        return issues
    }
}
