/// Oyuncunun geçici tahta durumu: her dönebilen okun başlangıçtan bu yana saat yönünde kaç adım (1–3) döndüğü.
/// Hamle sayısı tıklama geçmişinden değil bu durumdan hesaplanır (PLAN §1.3), bu yüzden Undo/Reset doğal çalışır.
public struct LevelState: Codable, Hashable, Sendable {
    /// Yalnız sıfırdan farklı döndürmeler tutulur; böylece aynı tahta her zaman eşit durum verir.
    public private(set) var rotations: [String: Int]

    public init(rotations: [String: Int] = [:]) {
        self.rotations = [:]
        for (id, steps) in rotations { setRotation(steps, for: id) }
    }

    public static let initial = LevelState()

    public var moves: Int { rotations.values.reduce(0, +) }

    public func rotation(of tileID: String) -> Int { rotations[tileID] ?? 0 }

    /// Taşın bu durumdaki yönü. Dönemeyen taşlar her zaman başlangıç yönündedir.
    public func direction(of tile: Tile) -> Direction? {
        guard let initial = tile.direction else { return nil }
        return tile.rotatable ? initial.rotated(by: rotation(of: tile.id)) : initial
    }

    /// Taşı saat yönünde 90° döndürür. Dönemeyen taşlarda durum değişmez.
    public func rotating(_ tile: Tile) -> LevelState {
        guard tile.rotatable, tile.direction != nil else { return self }
        var copy = self
        copy.setRotation(rotation(of: tile.id) + 1, for: tile.id)
        return copy
    }

    /// Taşı belirli bir yöne çevrilmiş durum (solver ve ipucu için).
    public func setting(_ tile: Tile, to direction: Direction) -> LevelState {
        guard tile.rotatable, let initial = tile.direction else { return self }
        var copy = self
        copy.setRotation(direction.clockwiseSteps(from: initial), for: tile.id)
        return copy
    }

    private mutating func setRotation(_ steps: Int, for id: String) {
        let normalized = (steps % 4 + 4) % 4
        rotations[id] = normalized == 0 ? nil : normalized
    }
}
