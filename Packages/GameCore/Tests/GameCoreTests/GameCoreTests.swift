import Testing
@testable import GameCore

@Test func schemaVersionIsOne() {
    #expect(GameCore.schemaVersion == 1)
}
