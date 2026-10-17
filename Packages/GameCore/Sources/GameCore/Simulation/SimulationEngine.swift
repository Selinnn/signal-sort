/// Saf ve deterministik simülasyon. Aynı (seviye, durum) her zaman aynı sonucu verir.
///
/// Her tick'te (PLAN §1.2):
/// 1. Her aktif sinyalin hedef hücresi hesaplanır.
/// 2. Tahta dışı → `outOfBounds`; engel veya kaynak hücresi → `blocked`.
/// 3. Yer değiştirme (A→B ve B→A) → `swapCollision`.
/// 4. Hareket uygulanır. Çıkış: doğru renk teslim edilir, yanlış renk → `wrongReceiver`.
///    Ok: yön okunur. Renkli ok: yalnız kendi rengi döner. Makas: mevcut yönü verilir. Köprü: düz geçiş.
/// 5. Aynı hücreye giren ≥2 sinyal → `collision` (çıkışlar hariç; köprüde yalnız aynı eksendekiler).
/// 6. Bu tick'te girilen her makas ok, giren sinyal başına 90° saat yönünde döner.
/// 7. Döngü → `loop`. Makassız tahtada: sinyal aynı (hücre, yön) durumuna döner.
///    Makaslı tahtada: tüm tahtanın durumu (aktif sinyaller + makas yönleri) tekrar eder.
/// İlk hata tick'inde simülasyon durur; o tick'teki tüm hatalar raporlanır.
public struct SimulationEngine: Sendable {
    public init() {}

    public func simulate(_ level: LevelDefinition, _ state: LevelState = .initial) -> SimulationResult {
        switch run(level, state, undecided: []) {
        case .finished(let result): result
        case .decisionNeeded: preconditionFailure("Karar beklenen taş yokken karar istenemez")
        }
    }

    /// Solver için: `undecided` içindeki taşların yönü henüz seçilmemiştir. Bir sinyal böyle bir taşa
    /// (renkli okta yalnız kendi rengi) girdiğinde simülasyon durur ve hangi taş için karar gerektiğini söyler.
    /// Aynı tick'te karardan bağımsız bir hata (dışarı çıkma, engel, çarpışma, yanlış çıkış) varsa o önceliklidir.
    enum Step {
        case finished(SimulationResult)
        case decisionNeeded(tileID: String)
    }

    func run(_ level: LevelDefinition, _ state: LevelState, undecided: Set<String>) -> Step {
        let board = Board(level: level, state: state, undecided: undecided)
        var signals = level.sources.map {
            Signal(id: $0.id, color: $0.color, coordinate: $0.coordinate, direction: $0.direction)
        }
        var toggles = board.initialToggleDirections
        var trace = [snapshot(tick: 0, signals, toggles, board)]
        var delivered: [String] = []
        var seenGlobalStates: Set<GlobalKey> = []
        let maxTicks = Self.tickLimit(level: level, toggleCount: toggles.count)

        for tick in 1...maxTicks {
            let activeIndices = signals.indices.filter { signals[$0].status == .active }
            if activeIndices.isEmpty { break }

            var failures: [SignalFailure] = []
            func fail(_ i: Int, _ reason: FailureReason, at coordinate: Coordinate, others: [String] = []) {
                signals[i].status = .failed
                failures.append(SignalFailure(signalID: signals[i].id, reason: reason, coordinate: coordinate, tick: tick, otherSignalIDs: others))
            }

            // 1–2. Hedefler, tahta dışı ve girilemeyen hücreler.
            var targets: [Int: Coordinate] = [:]
            for i in activeIndices {
                let target = signals[i].coordinate.moved(signals[i].direction)
                if !level.contains(target) {
                    fail(i, .outOfBounds, at: signals[i].coordinate)
                } else if board.impassable.contains(target) {
                    fail(i, .blocked, at: target)
                } else {
                    targets[i] = target
                }
            }

            // 3. Yer değiştirme. İki sinyal ancak aynı eksende yer değiştirebilir, köprü bunu engellemez.
            let movers = targets.keys.sorted()
            var swapped = Set<Int>()
            for (n, i) in movers.enumerated() {
                for j in movers[(n + 1)...] where targets[i] == signals[j].coordinate && targets[j] == signals[i].coordinate {
                    swapped.insert(i)
                    swapped.insert(j)
                }
            }
            let swapPartners = Dictionary(uniqueKeysWithValues: swapped.map { i in
                (i, swapped.filter { $0 != i && targets[$0] == signals[i].coordinate }.sorted().map { signals[$0].id })
            })
            for i in swapped.sorted() {
                fail(i, .swapCollision, at: signals[i].coordinate, others: swapPartners[i]!)
                targets[i] = nil
            }

            // 4. Hareket ve hücre etkileri.
            var occupants: [Occupancy: [Int]] = [:]
            var enteredToggles: [Int] = []
            var pendingDecision: String?
            for i in targets.keys.sorted() {
                let target = targets[i]!
                signals[i].coordinate = target
                if let receiver = board.receivers[target] {
                    if receiver.color == signals[i].color {
                        signals[i].status = .delivered
                        delivered.append(signals[i].id)
                    } else {
                        fail(i, .wrongReceiver, at: target)
                    }
                    continue
                }
                switch board.cells[target] {
                case .undecided(let tileID, let color) where color == nil || color == signals[i].color:
                    if pendingDecision == nil { pendingDecision = tileID }
                case .router(let direction):
                    signals[i].direction = direction
                case .colorRouter(let color, let direction) where color == signals[i].color:
                    signals[i].direction = direction
                case .toggle(let index):
                    signals[i].direction = toggles[index]
                    enteredToggles.append(index)
                case .colorRouter, .bridge, .undecided, nil:
                    break
                }
                let axis: Axis? = board.cells[target] == .bridge ? Axis(signals[i].direction) : nil
                occupants[Occupancy(coordinate: target, axis: axis), default: []].append(i)
            }

            // 5. Aynı hücrede (köprüde aynı eksende) çarpışma.
            for (cell, indices) in occupants where indices.count > 1 {
                for i in indices {
                    fail(i, .collision, at: cell.coordinate, others: indices.filter { $0 != i }.map { signals[$0].id })
                }
            }

            if failures.isEmpty, let tileID = pendingDecision {
                return .decisionNeeded(tileID: tileID)
            }

            // 6. Makas oklar döner.
            for index in enteredToggles { toggles[index] = toggles[index].clockwise }

            // 7. Döngü.
            if toggles.isEmpty {
                for i in targets.keys.sorted() where signals[i].status == .active {
                    let key = SignalKey(coordinate: signals[i].coordinate, direction: signals[i].direction)
                    if !signals[i].visited.insert(key).inserted {
                        fail(i, .loop, at: signals[i].coordinate)
                    }
                }
            } else if failures.isEmpty {
                do {
                    let active = signals.indices.filter { signals[$0].status == .active }
                    let key = GlobalKey(
                        signals: active.map { GlobalKey.Entry(index: $0, coordinate: signals[$0].coordinate, direction: signals[$0].direction) },
                        toggles: toggles)
                    if !active.isEmpty && !seenGlobalStates.insert(key).inserted {
                        for i in active { fail(i, .loop, at: signals[i].coordinate) }
                    }
                }
            }

            trace.append(snapshot(tick: tick, signals, toggles, board))
            if !failures.isEmpty {
                let order = Dictionary(uniqueKeysWithValues: signals.enumerated().map { ($1.id, $0) })
                failures.sort { order[$0.signalID]! < order[$1.signalID]! }
                return .finished(SimulationResult(outcome: .failure, trace: trace, deliveredSignalIDs: delivered, failures: failures))
            }
        }

        // Güvenlik ağı: döngü tespiti normalde bundan önce tetiklenir.
        let stuck = signals.filter { $0.status == .active }
        if !stuck.isEmpty {
            let tick = trace.last?.tick ?? 0
            let failures = stuck.map { SignalFailure(signalID: $0.id, reason: .loop, coordinate: $0.coordinate, tick: tick) }
            return .finished(SimulationResult(outcome: .failure, trace: trace, deliveredSignalIDs: delivered, failures: failures))
        }
        return .finished(SimulationResult(outcome: .success, trace: trace, deliveredSignalIDs: delivered, failures: []))
    }

    /// Makassız tahtada her sinyal en fazla W×H×4 farklı durumda bulunabilir. Makaslarla durum uzayı
    /// 4^makas katına çıkar; pratik bir tavanla sınırlanır.
    static func tickLimit(level: LevelDefinition, toggleCount: Int) -> Int {
        let base = max(level.width * level.height * 4, 1)
        var limit = base
        for _ in 0..<toggleCount where limit < 1_000_000 { limit *= 4 }
        return min(limit, 1_000_000) + 1
    }

    private func snapshot(tick: Int, _ signals: [Signal], _ toggles: [Direction], _ board: Board) -> TickSnapshot {
        TickSnapshot(
            tick: tick,
            signals: signals.map {
                SignalSnapshot(signalID: $0.id, color: $0.color, coordinate: $0.coordinate, direction: $0.direction, status: $0.status)
            },
            toggleDirections: Dictionary(uniqueKeysWithValues: board.toggleIDs.enumerated().map { ($1, toggles[$0]) }))
    }
}

private enum Axis: Hashable {
    case horizontal, vertical

    init(_ direction: Direction) {
        self = direction.dx != 0 ? .horizontal : .vertical
    }
}

private struct Occupancy: Hashable {
    var coordinate: Coordinate
    var axis: Axis?
}

private struct SignalKey: Hashable {
    var coordinate: Coordinate
    var direction: Direction
}

private struct GlobalKey: Hashable {
    struct Entry: Hashable {
        var index: Int
        var coordinate: Coordinate
        var direction: Direction
    }
    var signals: [Entry]
    var toggles: [Direction]
}

private struct Signal {
    let id: String
    let color: SignalColor
    var coordinate: Coordinate
    var direction: Direction
    var status: SignalStatus = .active
    var visited: Set<SignalKey> = []
}

private enum Cell: Equatable {
    case router(Direction)
    case colorRouter(SignalColor, Direction)
    /// Makas okların değişken yönü simülasyonda ayrı tutulur; burada indeksi saklanır.
    case toggle(Int)
    case bridge
    /// Solver: yönü henüz seçilmemiş taş. `color` doluysa yalnız o renk karar gerektirir (renkli ok).
    case undecided(tileID: String, color: SignalColor?)
}

/// Run boyunca değişmeyen hücre bilgisi. Değişen tek şey makas yönleridir.
private struct Board {
    var impassable: Set<Coordinate> = []
    var receivers: [Coordinate: Receiver] = [:]
    var cells: [Coordinate: Cell] = [:]
    var toggleIDs: [String] = []
    var initialToggleDirections: [Direction] = []

    init(level: LevelDefinition, state: LevelState, undecided: Set<String>) {
        for source in level.sources { impassable.insert(source.coordinate) }
        for receiver in level.receivers { receivers[receiver.coordinate] = receiver }
        for tile in level.tiles {
            let direction = state.direction(of: tile)
            if undecided.contains(tile.id) {
                cells[tile.coordinate] = .undecided(tileID: tile.id, color: tile.kind == .colorRouter ? tile.color : nil)
                continue
            }
            switch tile.kind {
            case .blocker:
                impassable.insert(tile.coordinate)
            case .bridge:
                cells[tile.coordinate] = .bridge
            case .router:
                if let direction { cells[tile.coordinate] = .router(direction) }
            case .colorRouter:
                if let direction, let color = tile.color { cells[tile.coordinate] = .colorRouter(color, direction) }
            case .toggle:
                guard let direction else { continue }
                cells[tile.coordinate] = .toggle(toggleIDs.count)
                toggleIDs.append(tile.id)
                initialToggleDirections.append(direction)
            }
        }
    }
}
