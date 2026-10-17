/// Izgara yönleri. Koordinat sistemi: (0,0) sol üst, x sağa, y aşağı doğru artar.
public enum Direction: String, Codable, CaseIterable, Sendable {
    case north, east, south, west

    /// Saat yönünde 90° × `steps` döndürülmüş yön. Negatif adımlar saat yönünün tersidir.
    public func rotated(by steps: Int) -> Direction {
        let all = Direction.allCases
        let index = all.firstIndex(of: self)!
        return all[((index + steps) % 4 + 4) % 4]
    }

    public var clockwise: Direction { rotated(by: 1) }

    public var opposite: Direction { rotated(by: 2) }

    public var dx: Int {
        switch self {
        case .east: 1
        case .west: -1
        case .north, .south: 0
        }
    }

    public var dy: Int {
        switch self {
        case .south: 1
        case .north: -1
        case .east, .west: 0
        }
    }

    /// `from` yönünden `self` yönüne saat yönünde kaç adım (0–3) gerektiği.
    public func clockwiseSteps(from: Direction) -> Int {
        let all = Direction.allCases
        return (all.firstIndex(of: self)! - all.firstIndex(of: from)! + 4) % 4
    }
}
