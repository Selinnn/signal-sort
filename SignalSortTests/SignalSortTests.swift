import GameCore
import Testing
@testable import SignalSort

@Test func appLinksGameCore() {
    #expect(GameCore.schemaVersion == 1)
}

@MainActor
@Test func bundledContentLoads() {
    #expect(LevelCatalog.bundled.levels.count == 150)
    #expect(DailyCatalog.bundled.pack?.levels.count == 730)
}
