public struct GeneratedLevel: Sendable {
    public var level: LevelDefinition
    public var metrics: LevelMetrics
    /// Kabul edilene kadar denenen aday sayısı.
    public var attempts: Int
}

public struct GenerationError: Error, CustomStringConvertible {
    public var seed: UInt64
    public var profile: String
    public var attempts: Int
    public var rejections: [QualityRejection: Int]

    public var description: String {
        let reasons = rejections.sorted { $0.value > $1.value }.map { "\($0.key.rawValue)=\($0.value)" }.joined(separator: " ")
        return "\(profile) tohum \(seed): \(attempts) denemede kabul edilebilir seviye yok (\(reasons))"
    }
}

/// "Önce çözüm kur, sonra karıştır, sonra doğrula" üreticisi (PLAN §6).
///
/// 1. Sinyaller sırayla, birer "yürüyücü" ile yerleştirilir. Yürüyücü önceki yolların zaman çizelgesini bilir:
///    aynı tick'te aynı hücre ve yer değiştirme yasaktır, mevcut taşların etkisine uyar, makas oka ancak önceki
///    tüm girişlerden sonra girer. Başka rengin düz geçtiği hücrede yalnız kendi renginde renkli okla döner;
///    aynı tick'te dik kesişmede (izinliyse) köprü koyar.
/// 2. Tuzak oklar ve engeller boş hücrelere (tercihen yolların yanına) konur.
/// 3. Dönebilir taşlar karıştırılır; çözülmüş hal motorla, karıştırılmış hal solver ve kalite filtresiyle doğrulanır.
/// Aynı (tohum, profil, sürüm) her zaman aynı seviyeyi verir.
public struct LevelGenerator: Sendable {
    /// Üretim algoritması veya profiller değişince artırılır; aynı tohum farklı seviye verebilir.
    public static let version = 1

    public var maxAttempts: Int
    public var filter = QualityFilter()

    public init(maxAttempts: Int = 400) {
        self.maxAttempts = maxAttempts
    }

    public func generate(seed: UInt64, profile: DifficultyProfile) throws -> GeneratedLevel {
        var rng = SplitMix64(seed: seed ^ StableHash.fnv1a("\(profile.name)#\(Self.version)"))
        var rejections: [QualityRejection: Int] = [:]
        let solver = Solver(maxSolutions: profile.maxSolutions + 1, maxNodes: profile.searchNodes.upperBound + 1)

        for attempt in 1...maxAttempts {
            guard let candidate = Draft.build(profile: profile, rng: &rng) else {
                rejections[.constructionFailed, default: 0] += 1
                continue
            }
            var level = candidate.level(id: "\(profile.name)-\(seed)", seed: seed, profile: profile, rng: &rng)
            let engine = SimulationEngine()
            guard engine.simulate(level, candidate.solvedState(in: level)).isSuccess else {
                rejections[.constructionFailed, default: 0] += 1
                continue
            }
            if engine.simulate(level).isSuccess {
                rejections[.startsSolved, default: 0] += 1
                continue
            }
            let report = solver.solve(level)
            if !report.isExhaustive {
                rejections[report.solutionCount > profile.maxSolutions ? .tooManySolutions : .searchTooLarge, default: 0] += 1
                continue
            }
            guard let metrics = LevelMetrics.measure(level, report: report) else {
                rejections[.unsolvable, default: 0] += 1
                continue
            }
            let problems = filter.evaluate(metrics, profile: profile)
            if let first = problems.first {
                rejections[first, default: 0] += 1
                continue
            }
            level.par = report.par
            level.solutionCount = report.solutionCount
            level.solutions = report.solutions
            return GeneratedLevel(level: level, metrics: metrics, attempts: attempt)
        }
        throw GenerationError(seed: seed, profile: profile.name, attempts: maxAttempts, rejections: rejections)
    }
}

// MARK: - Taslak (çözülmüş tahta)

private struct Visit {
    var tick: Int
    var signal: Int
    var color: SignalColor
    var direction: Direction
}

private struct DraftTile {
    var kind: TileKind
    /// Çözülmüş yön (makasta başlangıç yönü).
    var direction: Direction?
    var color: SignalColor?
    var onPath: Bool
}

private struct Draft {
    let width: Int
    let height: Int
    var sources: [Source] = []
    var receivers: [Receiver] = []
    var tiles: [Coordinate: DraftTile] = [:]
    /// Hücre → o hücreye girişler (yürüyücüler sırayla eklendikçe büyür).
    var visits: [Coordinate: [Visit]] = [:]
    /// (sinyal, tick) → hücre; çarpışma ve yer değiştirme kontrolü için.
    var positions: [Int: [Coordinate]] = [:]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    var cells: [Coordinate] {
        (0..<height).flatMap { y in (0..<width).map { Coordinate($0, y) } }
    }

    func contains(_ c: Coordinate) -> Bool {
        (0..<width).contains(c.x) && (0..<height).contains(c.y)
    }

    func isEndpoint(_ c: Coordinate) -> Bool {
        sources.contains { $0.coordinate == c } || receivers.contains { $0.coordinate == c }
    }

    /// Tamamen boş: taş, kaynak, çıkış yok ve hiçbir sinyal uğramamış.
    func isPristine(_ c: Coordinate) -> Bool {
        contains(c) && tiles[c] == nil && !isEndpoint(c) && (visits[c] ?? []).isEmpty
    }

    func position(of signal: Int, at tick: Int) -> Coordinate? {
        guard let path = positions[signal], tick < path.count else { return nil }
        return path[tick]
    }

    // MARK: İnşa

    static func build(profile: DifficultyProfile, rng: inout SplitMix64) -> Draft? {
        let size = rng.pick(profile.sizes)
        var draft = Draft(width: size.width, height: size.height)
        var colors = SignalColor.allCases.filter { $0 != .pink }
        rng.shuffle(&colors)
        let signalCount = rng.int(in: profile.signals)
        for index in 0..<signalCount {
            var placed = false
            for _ in 0..<12 {
                var trial = draft
                if trial.walk(signal: index, color: colors[index % colors.count], profile: profile, rng: &rng) {
                    draft = trial
                    placed = true
                    break
                }
            }
            if !placed { return nil }
        }
        draft.addExtras(profile: profile, rng: &rng)
        return draft
    }

    /// Bir sinyalin yolunu kurar. Başarısızsa false (taslak değiştirilmiş olabilir; çağıran kopyayla çalışır).
    mutating func walk(signal: Int, color: SignalColor, profile: DifficultyProfile, rng: inout SplitMix64) -> Bool {
        // Kaynak: boş hücre, ilk adımı tahta içinde ve boş/geçilebilir.
        var starts: [(Coordinate, Direction)] = []
        for cell in cells where isPristine(cell) {
            for direction in Direction.allCases {
                let next = cell.moved(direction)
                if contains(next) && tiles[next]?.kind != .blocker && !isEndpoint(next) { starts.append((cell, direction)) }
            }
        }
        guard !starts.isEmpty else { return false }
        let (start, startDirection) = rng.pick(starts)
        sources.append(Source(id: "s\(signal + 1)", color: color, at: start, direction: startDirection))
        positions[signal] = [start]

        let targetLength = rng.int(in: profile.pathLength)
        var position = start
        var heading = startDirection
        var tick = 0
        var seen: Set<String> = []

        while true {
            // Çıkış seçeneği: yol yeterince uzunsa önümüzdeki bozulmamış hücreye çıkış konabilir.
            let ahead = position.moved(heading)
            if tick >= profile.pathLength.lowerBound && isPristine(ahead) && !positions[signal]!.contains(ahead) {
                let endWeight = tick >= targetLength ? 50 : 2
                if rng.int(below: endWeight + 10) < endWeight {
                    receivers.append(Receiver(id: "d\(signal + 1)", color: color, at: ahead))
                    positions[signal]!.append(ahead)
                    visits[ahead, default: []].append(Visit(tick: tick + 1, signal: signal, color: color, direction: heading))
                    return true
                }
            }
            if tick >= profile.pathLength.upperBound { return false }

            // Bu hücreden çıkış yönleri: mevcut taş zorlar, boş hücrede düz veya taş koyarak dönüş.
            var options: [(direction: Direction, place: TileKind?, weight: Int)] = []
            if tick == 0 {
                options = [(heading, nil, 1)]
            } else if tiles[position] != nil {
                options = [(heading, nil, 1)]  // Yön girişte uygulandı.
            } else {
                // Bu hücreye daha önce (başka sinyal veya kendimiz) girildiyse düz geçmişlerdir; taş koymak onları
                // da çevirir. Yalnız onların hiçbirinin renginde olmayan renkli ok güvenlidir.
                let others = (visits[position] ?? []).filter { !($0.signal == signal && $0.tick == tick) }
                options.append((heading, nil, 3))
                for turn in [heading.rotated(by: 1), heading.rotated(by: -1)] {
                    if others.isEmpty {
                        if rng.chance(percent: profile.togglePercent) {
                            options.append((turn, .toggle, 2))
                        } else if rng.chance(percent: profile.colorRouterPercent / 3) {
                            options.append((turn, .colorRouter, 2))
                        } else {
                            options.append((turn, .router, 2))
                        }
                    } else if profile.colorRouterPercent > 0 && others.allSatisfy({ $0.color != color }) {
                        options.append((turn, .colorRouter, 2 + profile.colorRouterPercent / 10))
                    }
                }
            }

            // Hedef hücre kurallarına göre geçerli seçenekleri tart.
            var weights: [Int] = []
            var bridgeNeeded: [Bool] = []
            for option in options {
                let check = canEnter(option.direction, from: position, tick: tick + 1, signal: signal, color: color, profile: profile)
                bridgeNeeded.append(check.needsBridge)
                var weight = check.allowed ? option.weight : 0
                if check.allowed, let tile = tiles[position.moved(option.direction)], tile.kind == .toggle { weight += 4 }
                weights.append(weight)
            }
            guard let chosen = rng.weightedIndex(weights) else { return false }
            let option = options[chosen]

            if let kind = option.place {
                tiles[position] = DraftTile(kind: kind, direction: option.direction, color: kind == .colorRouter ? color : nil, onPath: true)
            }
            heading = option.direction
            position = position.moved(heading)
            tick += 1
            if bridgeNeeded[chosen] {
                tiles[position] = DraftTile(kind: .bridge, direction: nil, color: nil, onPath: true)
            }

            // Girişte taş etkisi.
            if let tile = tiles[position] {
                switch tile.kind {
                case .router:
                    heading = tile.direction!
                case .colorRouter where tile.color == color:
                    heading = tile.direction!
                case .toggle:
                    let earlier = (visits[position] ?? []).count
                    heading = tile.direction!.rotated(by: earlier)
                case .colorRouter, .bridge, .blocker:
                    break
                }
            }
            visits[position, default: []].append(Visit(tick: tick, signal: signal, color: color, direction: heading))
            positions[signal]!.append(position)
            if !seen.insert("\(position)\(heading)").inserted { return false }
        }
    }

    /// `from` hücresinden `direction` yönüne `tick` anında girmek, önceki yolları bozmadan mümkün mü.
    func canEnter(_ direction: Direction, from: Coordinate, tick: Int, signal: Int, color: SignalColor, profile: DifficultyProfile)
        -> (allowed: Bool, needsBridge: Bool)
    {
        let target = from.moved(direction)
        guard contains(target), !isEndpoint(target), tiles[target]?.kind != .blocker else { return (false, false) }
        // Kendi yoluna aynı yönde dönmek döngüdür; farklı yönden kesişmek serbest.
        let tile = tiles[target]
        if tile?.kind == .toggle {
            // Makas yönü giriş sırasına bağlı: önceki tüm girişlerden sonra girilmeli.
            if (visits[target] ?? []).contains(where: { $0.tick >= tick }) { return (false, false) }
        }
        var needsBridge = false
        for other in positions.keys.sorted() where other != signal {
            // Aynı tick aynı hücre.
            if position(of: other, at: tick) == target {
                let otherVisit = visits[target]?.first { $0.signal == other && $0.tick == tick }
                let perpendicular = otherVisit.map { ($0.direction.dx == 0) != (direction.dx == 0) } ?? false
                if tile?.kind == .bridge && perpendicular { continue }
                if tile == nil && profile.bridges && perpendicular { needsBridge = true; continue }
                return (false, false)
            }
            // Yer değiştirme.
            if position(of: other, at: tick - 1) == target && position(of: other, at: tick) == from { return (false, false) }
        }
        // Köprü konacak hücrede düz geçilmeli: diğer sinyal de orada düz geçiyor (hücre boş) olmalı.
        return (true, needsBridge)
    }

    /// Tuzak oklar ve engeller: önce yolların komşusu olan bozulmamış hücreler.
    mutating func addExtras(profile: DifficultyProfile, rng: inout SplitMix64) {
        func freeCells() -> [Coordinate] {
            let pristine = cells.filter { isPristine($0) }
            let nearPath = pristine.filter { c in Direction.allCases.contains { !(visits[c.moved($0)] ?? []).isEmpty } }
            return nearPath.isEmpty ? pristine : nearPath
        }
        for _ in 0..<rng.int(in: profile.blockers) {
            let free = freeCells()
            guard !free.isEmpty else { break }
            tiles[rng.pick(free)] = DraftTile(kind: .blocker, direction: nil, color: nil, onPath: false)
        }
        for _ in 0..<rng.int(in: profile.decoys) {
            let free = freeCells()
            guard !free.isEmpty else { break }
            let cell = rng.pick(free)
            // Çekici tuzak: yarı olasılıkla bir çıkışa doğru bakar.
            var direction = rng.pick(Direction.allCases)
            if rng.chance(percent: 50), let receiver = receivers.first {
                let dx = receiver.coordinate.x - cell.x, dy = receiver.coordinate.y - cell.y
                direction = abs(dx) >= abs(dy) ? (dx >= 0 ? .east : .west) : (dy >= 0 ? .south : .north)
            }
            let kind: TileKind = profile.colorRouterPercent > 0 && rng.chance(percent: 30) ? .colorRouter : .router
            tiles[cell] = DraftTile(kind: kind, direction: direction, color: kind == .colorRouter ? rng.pick(sources).color : nil, onPath: false)
        }
    }

    // MARK: Seviyeye dönüştürme

    /// Taşları karıştırır. Dönebilir yol taşlarının en az `minScrambled` kadarı yanlış yönde başlar.
    func level(id: String, seed: UInt64, profile: DifficultyProfile, rng: inout SplitMix64) -> LevelDefinition {
        var result: [Tile] = []
        var pathTileIDs: [String] = []
        var counter = 0
        for cell in cells {
            guard let draft = tiles[cell] else { continue }
            counter += 1
            let tileID = "t\(counter)"
            var rotatable = draft.kind.isDirectional
            if rotatable && draft.onPath && draft.kind != .toggle && rng.chance(percent: profile.fixedPercent) { rotatable = false }
            var direction = draft.direction
            if rotatable, let solved = draft.direction {
                // Yol taşları sonra karıştırılır; tuzaklar rastgele değil üretildiği (çekici) yönde kalır.
                direction = solved
                if draft.onPath { pathTileIDs.append(tileID) }
            }
            result.append(Tile(id: tileID, kind: draft.kind, at: cell, direction: direction, rotatable: rotatable, color: draft.color))
        }
        // Karıştırma: yol taşlarından rastgele bir alt küme kesin yanlış, kalanlar rastgele.
        var order = pathTileIDs
        rng.shuffle(&order)
        let forced = Set(order.prefix(profile.minScrambled + rng.int(below: 2)))
        for index in result.indices where pathTileIDs.contains(result[index].id) {
            let offset = forced.contains(result[index].id) ? rng.int(in: 1...3) : rng.int(below: 4)
            result[index].direction = result[index].direction!.rotated(by: offset)
        }
        return LevelDefinition(
            id: id, width: width, height: height, sources: sources, receivers: receivers, tiles: result,
            seed: seed, profile: profile.name, generatorVersion: LevelGenerator.version)
    }

    /// Taslaktaki çözülmüş yönler, seviyedeki taş ID'lerine göre.
    func solvedState(in level: LevelDefinition) -> LevelState {
        var state = LevelState.initial
        for tile in level.tiles {
            if let solved = tiles[tile.coordinate]?.direction { state = state.setting(tile, to: solved) }
        }
        return state
    }
}
