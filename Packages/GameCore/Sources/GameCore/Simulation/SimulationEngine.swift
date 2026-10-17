/// Saf ve deterministik simülasyon. Aynı (seviye, durum) her zaman aynı sonucu verir.
///
/// Her tick'te (PLAN §1.2):
/// 1. Her aktif sinyalin hedef hücresi hesaplanır.
/// 2. Tahta dışı → `outOfBounds`; engel veya kaynak hücresi → `blocked`.
/// 3. Yer değiştirme (A→B ve B→A) → `swapCollision`.
/// 4. Hareket uygulanır. Çıkış: doğru renk teslim edilir, yanlış renk → `wrongReceiver`. Ok hücresinde yön okunur.
/// 5. Aynı hücreye giren ≥2 sinyal → `collision` (çıkış hücreleri hariç).
/// 6. Döngü: sinyal daha önce bulunduğu (hücre, yön) durumuna dönerse → `loop`.
/// İlk hata tick'inde simülasyon durur; o tick'teki tüm hatalar raporlanır.
public struct SimulationEngine: Sendable {
    public init() {}

    public func simulate(_ level: LevelDefinition, _ state: LevelState = .initial) -> SimulationResult {
        let board = Board(level: level, state: state)
        var signals = level.sources.map {
            Signal(id: $0.id, color: $0.color, coordinate: $0.coordinate, direction: $0.direction)
        }
        var trace = [snapshot(tick: 0, signals)]
        var delivered: [String] = []
        // Her sinyal en fazla W×H×4 farklı (hücre, yön) durumunda bulunabilir; döngü tespiti bundan önce tetiklenir.
        let maxTicks = level.width * level.height * 4 + 1

        for tick in 1...max(maxTicks, 1) {
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
                } else if board.isImpassable(target) {
                    fail(i, .blocked, at: target)
                } else {
                    targets[i] = target
                }
            }

            // 3. Yer değiştirme.
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

            // 4. Hareket, çıkışlar ve oklar.
            var occupants: [Coordinate: [Int]] = [:]
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
                if let direction = board.routerDirections[target] {
                    signals[i].direction = direction
                }
                occupants[target, default: []].append(i)
            }

            // 5. Aynı hücrede çarpışma.
            for (cell, indices) in occupants where indices.count > 1 {
                for i in indices {
                    let others = indices.filter { $0 != i }.map { signals[$0].id }
                    fail(i, .collision, at: cell, others: others)
                }
            }

            // 6. Döngü.
            for i in targets.keys.sorted() where signals[i].status == .active {
                let key = SignalKey(coordinate: signals[i].coordinate, direction: signals[i].direction)
                if !signals[i].visited.insert(key).inserted {
                    fail(i, .loop, at: signals[i].coordinate)
                }
            }

            trace.append(snapshot(tick: tick, signals))
            if !failures.isEmpty {
                let order = Dictionary(uniqueKeysWithValues: signals.enumerated().map { ($1.id, $0) })
                failures.sort { order[$0.signalID]! < order[$1.signalID]! }
                return SimulationResult(outcome: .failure, trace: trace, deliveredSignalIDs: delivered, failures: failures)
            }
        }

        // Güvenlik ağı: döngü tespiti bunu imkânsız kılmalı.
        let stuck = signals.filter { $0.status == .active }
        if !stuck.isEmpty {
            let tick = trace.last?.tick ?? 0
            let failures = stuck.map { SignalFailure(signalID: $0.id, reason: .loop, coordinate: $0.coordinate, tick: tick) }
            return SimulationResult(outcome: .failure, trace: trace, deliveredSignalIDs: delivered, failures: failures)
        }
        return SimulationResult(outcome: .success, trace: trace, deliveredSignalIDs: delivered, failures: [])
    }

    private func snapshot(tick: Int, _ signals: [Signal]) -> TickSnapshot {
        TickSnapshot(tick: tick, signals: signals.map {
            SignalSnapshot(signalID: $0.id, color: $0.color, coordinate: $0.coordinate, direction: $0.direction, status: $0.status)
        })
    }
}

private struct SignalKey: Hashable {
    var coordinate: Coordinate
    var direction: Direction
}

private struct Signal {
    let id: String
    let color: SignalColor
    var coordinate: Coordinate
    var direction: Direction
    var status: SignalStatus = .active
    var visited: Set<SignalKey> = []
}

/// Simülasyon boyunca değişmeyen hücre bilgisi (oklar Run sırasında dönmez).
private struct Board {
    var impassable: Set<Coordinate> = []
    var receivers: [Coordinate: Receiver] = [:]
    var routerDirections: [Coordinate: Direction] = [:]

    init(level: LevelDefinition, state: LevelState) {
        for source in level.sources { impassable.insert(source.coordinate) }
        for receiver in level.receivers { receivers[receiver.coordinate] = receiver }
        for tile in level.tiles {
            switch tile.kind {
            case .blocker:
                impassable.insert(tile.coordinate)
            case .router:
                if let direction = state.direction(of: tile) { routerDirections[tile.coordinate] = direction }
            }
        }
    }

    func isImpassable(_ coordinate: Coordinate) -> Bool { impassable.contains(coordinate) }
}
