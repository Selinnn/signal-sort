@testable import GameCore

enum Fixtures {
    /// Doküman §11 örneği: tek çözüm, par 3.
    static let schemaExample = level(5, 5,
        sources: [src("s1", .orange, 0, 2, .east)],
        receivers: [dst("d1", .orange, 4, 2)],
        tiles: [router("r1", 1, 2, .south), router("r2", 2, 2, .east, rotatable: false), blocker("b1", 3, 1)])

    /// İki çözüm: A = r1 doğu, r2 güney, r4 güney (5 hamle); B = r1 güney, r3 doğu, r4 güney (4 hamle).
    /// `decoy` hiçbir çözümde ziyaret edilmez.
    static let twoRoutes = level(3, 3,
        sources: [src("s1", .orange, 0, 0, .east)],
        receivers: [dst("d1", .orange, 2, 2)],
        tiles: [router("r1", 1, 0, .north), router("r2", 2, 0, .north), router("r3", 1, 1, .east), router("r4", 2, 1, .north),
                router("decoy", 0, 2, .north)])
}
