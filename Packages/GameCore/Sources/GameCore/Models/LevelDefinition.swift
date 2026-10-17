/// Bir seviyenin değişmez tanımı. Oyuncunun değiştirdiği her şey `LevelState` içindedir.
public struct LevelDefinition: Codable, Hashable, Sendable {
    public var id: String
    public var schemaVersion: Int
    public var width: Int
    public var height: Int
    public var sources: [Source]
    public var receivers: [Receiver]
    public var tiles: [Tile]
    /// Solver'ın hesapladığı minimum hamle. Elle yazılmaz.
    public var par: Int?
    public var solutionCount: Int?
    /// Üreticiyle oluşturulduysa tohum; elle tasarlandıysa nil.
    public var seed: UInt64?

    public init(
        id: String,
        schemaVersion: Int = GameCore.schemaVersion,
        width: Int,
        height: Int,
        sources: [Source],
        receivers: [Receiver],
        tiles: [Tile] = [],
        par: Int? = nil,
        solutionCount: Int? = nil,
        seed: UInt64? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.width = width
        self.height = height
        self.sources = sources
        self.receivers = receivers
        self.tiles = tiles
        self.par = par
        self.solutionCount = solutionCount
        self.seed = seed
    }

    public func contains(_ coordinate: Coordinate) -> Bool {
        (0..<width).contains(coordinate.x) && (0..<height).contains(coordinate.y)
    }

    public func tile(withID id: String) -> Tile? {
        tiles.first { $0.id == id }
    }
}

/// Sinyal kaynağı. Kaynağın hücresi geçilemez; sinyal ilk tick'te `direction` yönündeki komşuya çıkar.
public struct Source: Codable, Hashable, Sendable {
    public var id: String
    public var color: SignalColor
    public var coordinate: Coordinate
    public var direction: Direction

    public init(id: String, color: SignalColor, at coordinate: Coordinate, direction: Direction) {
        self.id = id
        self.color = color
        self.coordinate = coordinate
        self.direction = direction
    }

    private enum CodingKeys: String, CodingKey { case id, color, x, y, dir }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        color = try c.decode(SignalColor.self, forKey: .color)
        coordinate = Coordinate(try c.decode(Int.self, forKey: .x), try c.decode(Int.self, forKey: .y))
        direction = try c.decode(Direction.self, forKey: .dir)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(color, forKey: .color)
        try c.encode(coordinate.x, forKey: .x)
        try c.encode(coordinate.y, forKey: .y)
        try c.encode(direction, forKey: .dir)
    }
}

/// Çıkış. Her yönden girilebilir; kendi rengindeki sınırsız sayıda sinyali kabul eder.
public struct Receiver: Codable, Hashable, Sendable {
    public var id: String
    public var color: SignalColor
    public var coordinate: Coordinate

    public init(id: String, color: SignalColor, at coordinate: Coordinate) {
        self.id = id
        self.color = color
        self.coordinate = coordinate
    }

    private enum CodingKeys: String, CodingKey { case id, color, x, y }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        color = try c.decode(SignalColor.self, forKey: .color)
        coordinate = Coordinate(try c.decode(Int.self, forKey: .x), try c.decode(Int.self, forKey: .y))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(color, forKey: .color)
        try c.encode(coordinate.x, forKey: .x)
        try c.encode(coordinate.y, forKey: .y)
    }
}

public enum TileKind: String, Codable, Sendable {
    /// Giren sinyalin yönünü okun yönü yapar.
    case router
    /// Girilemez hücre.
    case blocker
}

public struct Tile: Codable, Hashable, Sendable {
    public var id: String
    public var kind: TileKind
    public var coordinate: Coordinate
    /// Başlangıç yönü. Yönlü olmayan türlerde (engel) nil.
    public var direction: Direction?
    public var rotatable: Bool

    public init(id: String, kind: TileKind, at coordinate: Coordinate, direction: Direction? = nil, rotatable: Bool = false) {
        self.id = id
        self.kind = kind
        self.coordinate = coordinate
        self.direction = direction
        self.rotatable = rotatable
    }

    public static func router(_ id: String, at coordinate: Coordinate, _ direction: Direction, rotatable: Bool = true) -> Tile {
        Tile(id: id, kind: .router, at: coordinate, direction: direction, rotatable: rotatable)
    }

    public static func blocker(_ id: String, at coordinate: Coordinate) -> Tile {
        Tile(id: id, kind: .blocker, at: coordinate)
    }

    private enum CodingKeys: String, CodingKey { case id, kind, x, y, dir, rotatable }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(TileKind.self, forKey: .kind)
        coordinate = Coordinate(try c.decode(Int.self, forKey: .x), try c.decode(Int.self, forKey: .y))
        direction = try c.decodeIfPresent(Direction.self, forKey: .dir)
        rotatable = try c.decodeIfPresent(Bool.self, forKey: .rotatable) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(coordinate.x, forKey: .x)
        try c.encode(coordinate.y, forKey: .y)
        try c.encodeIfPresent(direction, forKey: .dir)
        if rotatable { try c.encode(true, forKey: .rotatable) }
    }
}
