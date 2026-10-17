/// Yıldız kuralları (PLAN §1.3): 3★ hamle ≤ par, 2★ hamle ≤ par+2, 1★ çözüldü. İpucu kullanılırsa en fazla 2★.
public enum Scoring {
    public static let maxStarsWithHint = 2

    public static func stars(moves: Int, par: Int, hintUsed: Bool) -> Int {
        let earned: Int
        if moves <= par {
            earned = 3
        } else if moves <= par + 2 {
            earned = 2
        } else {
            earned = 1
        }
        return hintUsed ? min(earned, maxStarsWithHint) : earned
    }
}
