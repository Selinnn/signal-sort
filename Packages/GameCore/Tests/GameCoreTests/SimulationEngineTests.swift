import Testing
@testable import GameCore

@Suite struct SimulationEngineTests {
    let engine = SimulationEngine()

    // MARK: Hareket

    @Test func signalTravelsStraightToReceiver() {
        let result = engine.simulate(level(5, 1, sources: [src("s1", .orange, 0, 0, .east)], receivers: [dst("d1", .orange, 4, 0)]))
        #expect(result.isSuccess)
        #expect(result.totalTicks == 4)
        #expect(result.deliveredSignalIDs == ["s1"])
        #expect(result.trace.map { $0.signals[0].coordinate.x } == [0, 1, 2, 3, 4])
        #expect(result.trace.last?.signals[0].status == .delivered)
    }

    @Test func routerTurnsSignalOnTheTickItEnters() {
        let result = engine.simulate(level(5, 5,
            sources: [src("s1", .orange, 0, 2, .east)],
            receivers: [dst("d1", .orange, 2, 4)],
            tiles: [router("r1", 2, 2, .south)]))
        #expect(result.isSuccess)
        #expect(result.trace[2].signals[0].coordinate == Coordinate(2, 2))
        #expect(result.trace[2].signals[0].direction == .south)
        #expect(result.totalTicks == 4)
    }

    /// PLAN §1.6: dokümandaki örnek. Başlangıçta başarısız, 3 saat yönü dönüşle çözülür.
    @Test func schemaExampleNeedsThreeClockwiseMoves() {
        let lvl = level(5, 5,
            sources: [src("s1", .orange, 0, 2, .east)],
            receivers: [dst("d1", .orange, 4, 2)],
            tiles: [router("r1", 1, 2, .south), router("r2", 2, 2, .east, rotatable: false), blocker("b1", 3, 1)])
        let initial = engine.simulate(lvl)
        #expect(initial.failures == [SignalFailure(signalID: "s1", reason: .outOfBounds, coordinate: Coordinate(1, 4), tick: 4)])

        var state = LevelState.initial
        for _ in 0..<3 { state = state.rotating(lvl.tiles[0]) }
        let solved = engine.simulate(lvl, state)
        #expect(solved.isSuccess)
        #expect(state.moves == 3)
    }

    @Test func emptyCellsKeepDirectionAndFixedRoutersStillTurn() {
        let result = engine.simulate(level(3, 3,
            sources: [src("s1", .blue, 0, 0, .east)],
            receivers: [dst("d1", .blue, 2, 2)],
            tiles: [router("r1", 2, 0, .south, rotatable: false)]))
        #expect(result.isSuccess)
        #expect(result.totalTicks == 4)
    }

    // MARK: Hata tipleri

    @Test func outOfBoundsReportsEdgeCell() {
        let result = engine.simulate(level(3, 1, sources: [src("s1", .orange, 0, 0, .east)]))
        #expect(result.failures == [SignalFailure(signalID: "s1", reason: .outOfBounds, coordinate: Coordinate(2, 0), tick: 3)])
        #expect(result.outcome == .failure)
    }

    @Test func blockerStopsSignal() {
        let result = engine.simulate(level(3, 1, sources: [src("s1", .orange, 0, 0, .east)], tiles: [blocker("b1", 1, 0)]))
        #expect(result.failures == [SignalFailure(signalID: "s1", reason: .blocked, coordinate: Coordinate(1, 0), tick: 1)])
        #expect(result.trace.last?.signals[0].coordinate == Coordinate(0, 0))
    }

    @Test func otherSourceCellIsImpassableAndPartialDeliveryIsReported() {
        let result = engine.simulate(level(3, 3,
            sources: [src("s1", .orange, 0, 0, .east), src("s2", .blue, 2, 0, .south)],
            receivers: [dst("d2", .blue, 2, 2)]))
        #expect(result.deliveredSignalIDs == ["s2"])
        #expect(result.failures == [SignalFailure(signalID: "s1", reason: .blocked, coordinate: Coordinate(2, 0), tick: 2)])
    }

    @Test func wrongColorReceiverFails() {
        let result = engine.simulate(level(3, 1, sources: [src("s1", .orange, 0, 0, .east)], receivers: [dst("d1", .blue, 2, 0)]))
        #expect(result.failures == [SignalFailure(signalID: "s1", reason: .wrongReceiver, coordinate: Coordinate(2, 0), tick: 2)])
    }

    @Test func sameTickCellEntryCollides() {
        let result = engine.simulate(level(3, 3, sources: [src("s1", .orange, 0, 1, .east), src("s2", .blue, 1, 0, .south)]))
        #expect(result.failures == [
            SignalFailure(signalID: "s1", reason: .collision, coordinate: Coordinate(1, 1), tick: 1, otherSignalIDs: ["s2"]),
            SignalFailure(signalID: "s2", reason: .collision, coordinate: Coordinate(1, 1), tick: 1, otherSignalIDs: ["s1"]),
        ])
    }

    @Test func headOnSwapCollides() {
        let result = engine.simulate(level(4, 1, sources: [src("s1", .orange, 0, 0, .east), src("s2", .blue, 3, 0, .west)]))
        #expect(result.failures == [
            SignalFailure(signalID: "s1", reason: .swapCollision, coordinate: Coordinate(1, 0), tick: 2, otherSignalIDs: ["s2"]),
            SignalFailure(signalID: "s2", reason: .swapCollision, coordinate: Coordinate(2, 0), tick: 2, otherSignalIDs: ["s1"]),
        ])
    }

    @Test func headOnMeetingInACellIsACollisionNotASwap() {
        let result = engine.simulate(level(5, 1, sources: [src("s1", .orange, 0, 0, .east), src("s2", .blue, 4, 0, .west)]))
        #expect(result.failures.map(\.reason) == [.collision, .collision])
        #expect(result.failures.allSatisfy { $0.coordinate == Coordinate(2, 0) && $0.tick == 2 })
    }

    @Test func loopIsDetectedWhenStateRepeats() {
        let result = engine.simulate(level(4, 3,
            sources: [src("s1", .orange, 0, 1, .east)],
            tiles: [router("a", 1, 1, .north), router("b", 1, 0, .east), router("c", 2, 0, .south), router("d", 2, 1, .west)]))
        #expect(result.failures == [SignalFailure(signalID: "s1", reason: .loop, coordinate: Coordinate(1, 1), tick: 5)])
    }

    @Test func simultaneousFailuresAreOrderedBySourceOrder() {
        let result = engine.simulate(level(2, 2, sources: [src("b", .blue, 0, 1, .south), src("a", .orange, 1, 0, .north)]))
        #expect(result.failures.map(\.signalID) == ["b", "a"])
        #expect(result.primaryFailure?.signalID == "b")
    }

    // MARK: Paylaşım ve zamanlama

    @Test func receiversAcceptSeveralSignalsOnTheSameTick() {
        let result = engine.simulate(level(3, 3,
            sources: [src("s1", .orange, 0, 1, .east), src("s2", .orange, 2, 1, .west)],
            receivers: [dst("d1", .orange, 1, 1)]))
        #expect(result.isSuccess)
        #expect(result.deliveredSignalIDs == ["s1", "s2"])
        #expect(result.totalTicks == 1)
    }

    @Test func crossingOnDifferentTicksIsAllowed() {
        let result = engine.simulate(level(7, 5,
            sources: [src("s1", .orange, 0, 2, .east), src("s2", .blue, 3, 0, .south)],
            receivers: [dst("d1", .orange, 6, 2), dst("d2", .blue, 3, 4)]))
        #expect(result.isSuccess)
        #expect(result.deliveredSignalIDs == ["s2", "s1"])
    }

    @Test func followingIntoAJustVacatedCellIsAllowed() {
        let result = engine.simulate(level(4, 3,
            sources: [src("s1", .orange, 0, 1, .east), src("s2", .blue, 2, 0, .west)],
            receivers: [dst("d1", .orange, 3, 1), dst("d2", .blue, 1, 2)],
            tiles: [router("r1", 1, 0, .south, rotatable: false)]))
        #expect(result.isSuccess)
    }

    @Test func noSourcesSucceedsImmediately() {
        let result = engine.simulate(level(3, 3, sources: []))
        #expect(result.isSuccess)
        #expect(result.totalTicks == 0)
    }
}
