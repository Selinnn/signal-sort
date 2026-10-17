public struct Coordinate: Hashable, Codable, Sendable, CustomStringConvertible {
    public var x: Int
    public var y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    public func moved(_ direction: Direction) -> Coordinate {
        Coordinate(x + direction.dx, y + direction.dy)
    }

    public var description: String { "(\(x),\(y))" }
}
