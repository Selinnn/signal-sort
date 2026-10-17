/// Tohumlanabilir, platformdan bağımsız PRNG (SplitMix64). Üretici yalnız bunu kullanır:
/// Swift'in `SystemRandomNumberGenerator`'ı tohum almaz ve stdlib'in `random(in:)`/`shuffle` algoritmaları
/// sürümler arasında değişebilir, bu yüzden aralık, karıştırma ve seçim burada tanımlıdır.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0..<n aralığında tarafsız tamsayı (reddetmeli örnekleme).
    public mutating func int(below n: Int) -> Int {
        precondition(n > 0)
        let bound = UInt64(n)
        let threshold = (0 &- bound) % bound
        while true {
            let r = next()
            if r >= threshold { return Int(r % bound) }
        }
    }

    public mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + int(below: range.upperBound - range.lowerBound + 1)
    }

    public mutating func chance(percent: Int) -> Bool {
        int(below: 100) < percent
    }

    public mutating func pick<T>(_ items: [T]) -> T {
        items[int(below: items.count)]
    }

    /// Fisher–Yates.
    public mutating func shuffle<T>(_ items: inout [T]) {
        guard items.count > 1 else { return }
        for i in stride(from: items.count - 1, to: 0, by: -1) {
            items.swapAt(i, int(below: i + 1))
        }
    }

    /// Ağırlıklara göre indeks seçer. Tüm ağırlıklar 0 ise nil.
    public mutating func weightedIndex(_ weights: [Int]) -> Int? {
        let total = weights.reduce(0, +)
        guard total > 0 else { return nil }
        var roll = int(below: total)
        for (index, weight) in weights.enumerated() {
            if roll < weight { return index }
            roll -= weight
        }
        return nil
    }
}

/// Süreçten sürece değişmeyen hash (Swift `Hasher` her açılışta farklı tohum kullanır).
public enum StableHash {
    public static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}
