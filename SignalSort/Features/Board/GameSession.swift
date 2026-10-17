import GameCore
import Observation
import SwiftUI

enum PlaybackSpeed: CaseIterable {
    case normal, fast

    var tickDuration: Double {
        switch self {
        case .normal: 0.30
        case .fast: 0.14
        }
    }
}

/// Board ekranının durumu: `PlaySession`'ı sarar, Run animasyonunu (trace oynatma) ve ok açılarını yönetir.
/// Oyun kuralları burada değil GameCore'dadır; bu sınıf yalnız girdiyi iletir ve sonucu oynatır.
@MainActor
@Observable
final class GameSession {
    enum Phase: Equatable {
        case planning, playing, finished
    }

    /// UI testleri animasyonu hızlandırmak için küçültür.
    static var tickScale: Double = 1

    private(set) var play: PlaySession
    private(set) var phase: Phase = .planning
    private(set) var playbackTick = 0
    private(set) var hintTileID: String?
    private(set) var tileAngles: [String: Double] = [:]
    var speed: PlaybackSpeed = .normal
    /// Reduce Motion açıksa Run sonucu animasyonsuz gösterilir.
    var instantPlayback = false

    private var playbackTask: Task<Void, Never>?

    init(level: LevelDefinition) {
        play = PlaySession(level: level)
        for tile in level.tiles {
            if let direction = tile.direction { tileAngles[tile.id] = direction.degrees }
        }
    }

    var level: LevelDefinition { play.level }
    var result: SimulationResult? { play.lastResult }
    var tickDuration: Double { speed.tickDuration * Self.tickScale }
    var isInteractive: Bool { phase != .playing && !play.isSolved }
    var showsResult: Bool { phase == .finished && play.isSolved }

    /// Oynatılan veya sonlanmış Run'ın o anki karesi. Planlama sırasında nil.
    var snapshot: TickSnapshot? {
        guard phase != .planning, let result else { return nil }
        return result.trace[min(playbackTick, result.trace.count - 1)]
    }

    /// Hata işaretleri yalnız oynatma bittiğinde gösterilir.
    var visibleFailures: [SignalFailure] {
        phase == .finished ? result?.failures ?? [] : []
    }

    func color(ofSignal id: String) -> SignalColor? {
        level.sources.first { $0.id == id }?.color
    }

    // MARK: Girdi

    func tap(_ tile: Tile) {
        guard isInteractive, play.rotate(tile.id) else { return }
        phase = .planning
        hintTileID = nil
        updateAngles(clockwise: true)
    }

    func undo() {
        guard isInteractive, play.canUndo else { return }
        play.undo()
        phase = .planning
        hintTileID = nil
        updateAngles(clockwise: false)
    }

    func reset() {
        guard isInteractive, play.canReset else { return }
        play.reset()
        phase = .planning
        hintTileID = nil
        updateAngles(clockwise: false)
    }

    /// İpucu verilebilecek durum var mı (çözülmemiş, oynatma yok ve yanlış taş var).
    var canHint: Bool {
        guard isInteractive else { return false }
        var probe = play
        return probe.takeHint() != nil
    }

    /// İpucunu uygular. Uygulandıysa true (çağıran bakiyeden düşer).
    @discardableResult
    func hint() -> Bool {
        guard isInteractive, let hint = play.takeHint() else { return false }
        phase = .planning
        hintTileID = hint.tileID
        updateAngles(clockwise: true)
        return true
    }

    func toggleSpeed() {
        speed = speed == .normal ? .fast : .normal
    }

    // MARK: Run

    func run() {
        guard isInteractive else { return }
        let result = play.run()
        hintTileID = nil
        playbackTask?.cancel()
        playbackTick = 0
        if instantPlayback {
            playbackTick = result.totalTicks
            phase = .finished
            return
        }
        phase = .playing
        playbackTask = Task { [weak self] in
            guard let self else { return }
            for tick in 1...max(result.totalTicks, 1) {
                withAnimation(.linear(duration: self.tickDuration)) { self.playbackTick = tick }
                try? await Task.sleep(for: .seconds(self.tickDuration))
                if Task.isCancelled { return }
            }
            withAnimation(.easeOut(duration: 0.2)) { self.phase = .finished }
        }
    }

    /// Animasyonu atlar ve sonucu hemen gösterir.
    func skip() {
        guard phase == .playing, let result else { return }
        playbackTask?.cancel()
        playbackTick = result.totalTicks
        phase = .finished
    }

    // MARK: Ok açıları

    /// Taşın ekrandaki açısı. Oynatma sırasında makas okların o ana kadarki dönüşleri eklenir.
    func angle(for tile: Tile) -> Double {
        let base = tileAngles[tile.id] ?? 0
        guard tile.kind == .toggle, let result, phase != .planning else { return base }
        var turns = 0
        let last = min(playbackTick, result.trace.count - 1)
        if last >= 1 {
            for tick in 1...last {
                if let before = result.trace[tick - 1].toggleDirections[tile.id], let after = result.trace[tick].toggleDirections[tile.id] {
                    turns += after.clockwiseSteps(from: before)
                }
            }
        }
        return base + Double(turns) * 90
    }

    /// Yeni yönlere geçerken okların doğru yönde dönmesi için açıları biriktirir
    /// (ör. batı→kuzey dönüşü 270°→0° değil 270°→360° olmalı).
    private func updateAngles(clockwise: Bool) {
        for tile in level.tiles {
            guard let direction = play.state.direction(of: tile) else { continue }
            let old = tileAngles[tile.id] ?? direction.degrees
            var diff = (direction.degrees - old).truncatingRemainder(dividingBy: 360)
            if diff < 0 { diff += 360 }
            if !clockwise && diff > 180 { diff -= 360 }
            tileAngles[tile.id] = old + diff
        }
    }
}
