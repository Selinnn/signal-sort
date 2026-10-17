/// Bir seviyenin oynanış mantığı: döndür, geri al, sıfırla, çalıştır, ipucu. UI'dan bağımsızdır;
/// uygulamadaki `GameSession` bunu sarar ve animasyon ekler, bot oyuncu ve testler doğrudan kullanır.
public struct PlaySession: Sendable {
    public let level: LevelDefinition
    public private(set) var state: LevelState = .initial
    /// Geri alma yığını: her değişiklikten önceki durum.
    public private(set) var history: [LevelState] = []
    /// Son Run sonucu. Tahta değişince temizlenir (eski iz artık geçerli değildir).
    public private(set) var lastResult: SimulationResult?
    public private(set) var runCount = 0
    public private(set) var hintsUsed = 0

    public init(level: LevelDefinition) {
        self.level = level
    }

    public var isSolved: Bool { lastResult?.isSuccess == true }
    public var moves: Int { state.moves }
    public var par: Int? { level.par }
    public var canUndo: Bool { !history.isEmpty && !isSolved }
    public var canReset: Bool { state != .initial && !isSolved }
    public var hintUsed: Bool { hintsUsed > 0 }

    public var stars: Int? {
        guard isSolved, let par else { return nil }
        return Scoring.stars(moves: moves, par: par, hintUsed: hintUsed)
    }

    /// Taşı saat yönünde döndürür. Dönemeyen taşta veya çözülmüş seviyede false.
    @discardableResult
    public mutating func rotate(_ tileID: String) -> Bool {
        guard !isSolved, let tile = level.tile(withID: tileID), tile.rotatable, tile.kind.isDirectional else { return false }
        apply(state.rotating(tile))
        return true
    }

    public mutating func undo() {
        guard canUndo else { return }
        state = history.removeLast()
        lastResult = nil
    }

    /// Başlangıca döner; geri alınabilir.
    public mutating func reset() {
        guard canReset else { return }
        apply(.initial)
    }

    @discardableResult
    public mutating func run() -> SimulationResult {
        if isSolved, let lastResult { return lastResult }
        runCount += 1
        let result = SimulationEngine().simulate(level, state)
        lastResult = result
        return result
    }

    /// İpucunu hesaplar ve uygular (yanlış taşı doğru yöne çevirir).
    public mutating func takeHint() -> Hint? {
        guard !isSolved else { return nil }
        let solutions = level.solutions ?? Solver().solve(level).solutions
        guard let hint = HintProvider().hint(level, state, solutions: solutions),
              let tile = level.tile(withID: hint.tileID) else { return nil }
        hintsUsed += 1
        apply(state.setting(tile, to: hint.targetDirection))
        return hint
    }

    private mutating func apply(_ newState: LevelState) {
        guard newState != state else { return }
        history.append(state)
        state = newState
        lastResult = nil
    }
}
