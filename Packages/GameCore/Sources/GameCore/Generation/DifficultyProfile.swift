public struct BoardSize: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int

    public init(_ width: Int, _ height: Int) {
        self.width = width
        self.height = height
    }
}

/// Üretilen seviyede bulunması zorunlu, anlamlı mekanik kullanımı.
public enum MechanicRequirement: String, Codable, Sendable {
    /// Renkli oktan hem kendi rengi (döner) hem başka bir renk (düz geçer) geçer.
    case colorRouterShare
    /// Makas oka en az iki kez girilir.
    case toggleMultiEntry
    /// Köprüde iki sinyal kesişir.
    case bridgeCrossing
}

/// Bir bölüm/günlük zorluğu için üretim parametreleri ve kabul bantları.
public struct DifficultyProfile: Codable, Hashable, Sendable {
    public var name: String
    public var sizes: [BoardSize]
    public var signals: ClosedRange<Int>
    /// Kaynak ile çıkış arasındaki hücre sayısı (çıkış dahil değil).
    public var pathLength: ClosedRange<Int>
    /// Yol üstündeki yönlü taşların sabit (dönemez) olma olasılığı.
    public var fixedPercent: Int
    public var decoys: ClosedRange<Int>
    public var blockers: ClosedRange<Int>
    /// Dönüş yapılacak boş hücrede renkli ok / makas kullanma olasılığı; paylaşılan hücrede renkli ok ağırlığı.
    public var colorRouterPercent: Int
    public var togglePercent: Int
    public var bridges: Bool
    public var requirements: [MechanicRequirement]
    /// Par çözümünde en az iki farklı sinyalin uğradığı hücre sayısı.
    public var minSharedCells: Int
    /// Par çözümünde sinyallerin girdiği dönebilir taş sayısı (gerçek karar sayısı).
    public var minDecisions: Int
    /// Başlangıçta yanlış yönde olan çözüm taşı sayısı.
    public var minScrambled: Int
    public var par: ClosedRange<Int>
    public var searchNodes: ClosedRange<Int>
    public var maxSolutions: Int

    public static let route = DifficultyProfile(
        name: "route", sizes: [BoardSize(5, 5)], signals: 1...1, pathLength: 6...12,
        fixedPercent: 0, decoys: 0...2, blockers: 0...0, colorRouterPercent: 0, togglePercent: 0, bridges: false,
        requirements: [], minSharedCells: 0, minDecisions: 2, minScrambled: 2,
        par: 2...8, searchNodes: 2...300, maxSolutions: 2)

    public static let obstacle = DifficultyProfile(
        name: "obstacle", sizes: [BoardSize(5, 5), BoardSize(6, 6)], signals: 1...2, pathLength: 7...14,
        fixedPercent: 25, decoys: 1...3, blockers: 2...5, colorRouterPercent: 0, togglePercent: 0, bridges: false,
        requirements: [], minSharedCells: 0, minDecisions: 3, minScrambled: 2,
        par: 3...10, searchNodes: 4...1_500, maxSolutions: 2)

    public static let crossing = DifficultyProfile(
        name: "crossing", sizes: [BoardSize(6, 6)], signals: 2...3, pathLength: 6...14,
        fixedPercent: 20, decoys: 1...3, blockers: 0...3, colorRouterPercent: 0, togglePercent: 0, bridges: false,
        requirements: [], minSharedCells: 1, minDecisions: 4, minScrambled: 3,
        par: 4...12, searchNodes: 8...5_000, maxSolutions: 3)

    public static let color = DifficultyProfile(
        name: "color", sizes: [BoardSize(6, 6)], signals: 2...3, pathLength: 6...14,
        fixedPercent: 15, decoys: 1...3, blockers: 0...3, colorRouterPercent: 70, togglePercent: 0, bridges: false,
        requirements: [.colorRouterShare], minSharedCells: 1, minDecisions: 4, minScrambled: 3,
        par: 4...12, searchNodes: 8...5_000, maxSolutions: 3)

    public static let toggle = DifficultyProfile(
        name: "toggle", sizes: [BoardSize(6, 6), BoardSize(7, 7)], signals: 2...3, pathLength: 6...16,
        fixedPercent: 15, decoys: 1...3, blockers: 0...3, colorRouterPercent: 20, togglePercent: 40, bridges: false,
        requirements: [.toggleMultiEntry], minSharedCells: 1, minDecisions: 4, minScrambled: 3,
        par: 4...14, searchNodes: 8...10_000, maxSolutions: 3)

    public static let master = DifficultyProfile(
        name: "master", sizes: [BoardSize(7, 7)], signals: 3...4, pathLength: 7...16,
        fixedPercent: 15, decoys: 2...4, blockers: 0...4, colorRouterPercent: 50, togglePercent: 25, bridges: true,
        requirements: [.colorRouterShare], minSharedCells: 2, minDecisions: 6, minScrambled: 4,
        par: 6...18, searchNodes: 20...30_000, maxSolutions: 3)

    public static let all: [DifficultyProfile] = [.route, .obstacle, .crossing, .color, .toggle, .master]

    public static func named(_ name: String) -> DifficultyProfile? {
        all.first { $0.name == name }
    }
}
