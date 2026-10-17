/// Seviyeler arası benzerlik (PLAN §6.3): döndürme ve yansıma dahil 8 simetri altında hücre karşılaştırması.
/// Renkler yok sayılır; iki seviye renk değişimiyle aynıysa yine benzer sayılır.
public enum LevelFingerprint {
    /// Boş olmayan hücrelerin kodları (koordinat → kod), verilen simetri altında.
    static func cells(_ level: LevelDefinition, transform: Int) -> (width: Int, height: Int, cells: [Coordinate: String]) {
        var width = level.width, height = level.height
        var map: [Coordinate: String] = [:]
        let place = { (c: Coordinate, text: String, direction: Direction?) in
            let (point, _) = transformed(c, level.width, level.height, transform)
            map[point] = text + (direction.map { String(transformed($0, transform).rawValue.prefix(1)) } ?? "")
        }
        for source in level.sources { place(source.coordinate, "S", source.direction) }
        for receiver in level.receivers { place(receiver.coordinate, "R", nil) }
        for tile in level.tiles {
            let rotatableMark = tile.rotatable ? "*" : ""
            place(tile.coordinate, tile.kind.rawValue + rotatableMark, tile.direction)
        }
        if transform % 2 == 1 { swap(&width, &height) }
        return (width, height, map)
    }

    /// 0…1: en benzer simetride, iki seviyenin boş olmayan hücrelerinden aynı olanların oranı.
    public static func similarity(_ a: LevelDefinition, _ b: LevelDefinition) -> Double {
        let base = cells(a, transform: 0)
        var best = 0.0
        for transform in 0..<8 {
            let other = cells(b, transform: transform)
            guard other.width == base.width, other.height == base.height else { continue }
            let positions = Set(base.cells.keys).union(other.cells.keys)
            guard !positions.isEmpty else { return 1 }
            let same = positions.filter { base.cells[$0] == other.cells[$0] }.count
            best = max(best, Double(same) / Double(positions.count))
        }
        return best
    }

    /// Sıralı simetri: önce (yansıma varsa) yatay yansıma, sonra saat yönünde `transform % 4` kez 90°.
    static func transformed(_ c: Coordinate, _ width: Int, _ height: Int, _ transform: Int) -> (Coordinate, (Int, Int)) {
        var point = transform >= 4 ? Coordinate(width - 1 - c.x, c.y) : c
        var w = width, h = height
        for _ in 0..<(transform % 4) {
            point = Coordinate(h - 1 - point.y, point.x)
            swap(&w, &h)
        }
        return (point, (w, h))
    }

    static func transformed(_ direction: Direction, _ transform: Int) -> Direction {
        var d = direction
        if transform >= 4 {
            d = switch d {
            case .east: .west
            case .west: .east
            default: d
            }
        }
        return d.rotated(by: transform % 4)
    }
}
