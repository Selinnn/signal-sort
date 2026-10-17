@testable import GameCore

func src(_ id: String, _ color: SignalColor, _ x: Int, _ y: Int, _ direction: Direction) -> Source {
    Source(id: id, color: color, at: Coordinate(x, y), direction: direction)
}

func dst(_ id: String, _ color: SignalColor, _ x: Int, _ y: Int) -> Receiver {
    Receiver(id: id, color: color, at: Coordinate(x, y))
}

func router(_ id: String, _ x: Int, _ y: Int, _ direction: Direction, rotatable: Bool = true) -> Tile {
    .router(id, at: Coordinate(x, y), direction, rotatable: rotatable)
}

func blocker(_ id: String, _ x: Int, _ y: Int) -> Tile {
    .blocker(id, at: Coordinate(x, y))
}

func colorRouter(_ id: String, _ color: SignalColor, _ x: Int, _ y: Int, _ direction: Direction, rotatable: Bool = true) -> Tile {
    .colorRouter(id, color, at: Coordinate(x, y), direction, rotatable: rotatable)
}

func toggle(_ id: String, _ x: Int, _ y: Int, _ direction: Direction, rotatable: Bool = true) -> Tile {
    .toggle(id, at: Coordinate(x, y), direction, rotatable: rotatable)
}

func bridge(_ id: String, _ x: Int, _ y: Int) -> Tile {
    .bridge(id, at: Coordinate(x, y))
}

func level(_ width: Int, _ height: Int, sources: [Source], receivers: [Receiver] = [], tiles: [Tile] = []) -> LevelDefinition {
    LevelDefinition(id: "test", width: width, height: height, sources: sources, receivers: receivers, tiles: tiles)
}

/// Testlerde tekrarlanabilir rastgelelik (üretim PRNG'si 5. adımda GameCore'a eklenecek).
struct TestRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
