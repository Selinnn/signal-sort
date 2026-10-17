/// Tahtayı terminal için metne çevirir (CLI ve hata ayıklama). Her hücre 3 karakter:
///  ·  boş   #  engel   +  köprü   S→o kaynak (yön, renk)   [o] çıkış
///  →  dönebilir ok   (→) sabit ok   b→ renkli ok (mavi)   ~→ makas ok
public enum BoardRenderer {
    public static func render(_ level: LevelDefinition, _ state: LevelState = .initial) -> String {
        var grid = Array(repeating: Array(repeating: " · ", count: level.width), count: level.height)
        func put(_ c: Coordinate, _ text: String) {
            if level.contains(c) { grid[c.y][c.x] = text }
        }
        for tile in level.tiles {
            let arrow = state.direction(of: tile).map(symbol) ?? "?"
            switch tile.kind {
            case .blocker: put(tile.coordinate, " # ")
            case .bridge: put(tile.coordinate, " + ")
            case .router: put(tile.coordinate, tile.rotatable ? " \(arrow) " : "(\(arrow))")
            case .colorRouter: put(tile.coordinate, "\(letter(tile.color))\(arrow)\(tile.rotatable ? " " : ")")")
            case .toggle: put(tile.coordinate, "~\(arrow)\(tile.rotatable ? " " : ")")")
            }
        }
        for source in level.sources { put(source.coordinate, "S\(symbol(source.direction))\(letter(source.color))") }
        for receiver in level.receivers { put(receiver.coordinate, "[\(letter(receiver.color))]") }
        return grid.map { $0.joined() }.joined(separator: "\n")
    }

    static func symbol(_ direction: Direction) -> String {
        switch direction {
        case .north: "↑"
        case .east: "→"
        case .south: "↓"
        case .west: "←"
        }
    }

    static func letter(_ color: SignalColor?) -> String {
        switch color {
        case .orange: "o"
        case .blue: "b"
        case .green: "g"
        case .yellow: "y"
        case .pink: "p"
        case nil: "?"
        }
    }
}
