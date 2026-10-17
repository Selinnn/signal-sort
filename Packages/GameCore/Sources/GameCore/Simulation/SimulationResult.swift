public enum FailureReason: String, Codable, Sendable {
    /// Sinyal tahtanın dışına çıkmaya çalıştı. Koordinat: sinyalin kenardaki son hücresi.
    case outOfBounds
    /// Engel veya kaynak hücresine girmeye çalıştı. Koordinat: girilemeyen hücre.
    case blocked
    /// İki sinyal aynı tick'te yer değiştirmeye çalıştı (birbirinin içinden geçme). Koordinat: sinyalin kendi hücresi.
    case swapCollision
    /// Yanlış renkli çıkışa girdi. Koordinat: çıkış.
    case wrongReceiver
    /// İki veya daha fazla sinyal aynı tick'te aynı hücreye girdi. Koordinat: o hücre.
    case collision
    /// Sinyal daha önce bulunduğu durumuna geri döndü (makaslı tahtalarda tüm tahtanın durumu). Koordinat: sinyalin hücresi.
    case loop
}

public struct SignalFailure: Codable, Hashable, Sendable {
    public var signalID: String
    public var reason: FailureReason
    public var coordinate: Coordinate
    public var tick: Int
    /// Çarpışmalarda karşı sinyal(ler).
    public var otherSignalIDs: [String]

    public init(signalID: String, reason: FailureReason, coordinate: Coordinate, tick: Int, otherSignalIDs: [String] = []) {
        self.signalID = signalID
        self.reason = reason
        self.coordinate = coordinate
        self.tick = tick
        self.otherSignalIDs = otherSignalIDs
    }
}

public enum SignalStatus: String, Codable, Sendable {
    case active, delivered, failed
}

public struct SignalSnapshot: Codable, Hashable, Sendable {
    public var signalID: String
    public var color: SignalColor
    public var coordinate: Coordinate
    public var direction: Direction
    public var status: SignalStatus
}

/// Bir tick sonundaki tüm sinyallerin durumu. Tick 0 = sinyaller kaynaklarında.
public struct TickSnapshot: Codable, Hashable, Sendable {
    public var tick: Int
    public var signals: [SignalSnapshot]
    /// Makas okların tick sonundaki yönleri (taş ID → yön). Makas yoksa boş.
    public var toggleDirections: [String: Direction] = [:]
}

public struct SimulationResult: Codable, Hashable, Sendable {
    public enum Outcome: String, Codable, Sendable { case success, failure }

    public var outcome: Outcome
    /// UI animasyonunun tek kaynağı.
    public var trace: [TickSnapshot]
    /// Teslim edilen sinyaller (kaynak ID'leri), teslim sırasıyla.
    public var deliveredSignalIDs: [String]
    /// Simülasyonu bitiren tick'teki tüm hatalar, kaynak sırasına göre. UI ilkini vurgular.
    public var failures: [SignalFailure]

    public var totalTicks: Int { trace.last?.tick ?? 0 }
    public var isSuccess: Bool { outcome == .success }
    public var primaryFailure: SignalFailure? { failures.first }
}
