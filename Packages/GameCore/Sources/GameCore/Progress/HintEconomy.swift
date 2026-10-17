/// İpucu ekonomisi (PLAN §3.3). Değerler tek yerde; mağaza ve testler buradan okur.
public enum HintEconomy {
    public static let startingHints = 3
    /// Her günün bulmacası ilk kez çözülünce.
    public static let dailyReward = 1
    /// Tam Oyun satın alınınca bir kez.
    public static let fullGameBonus = 20
    /// İpucu paketi (consumable).
    public static let packSize = 10
    /// Ödüllü reklam başına (adım 11) ve günlük sınırı.
    public static let rewardedAdHints = 1
    public static let rewardedAdDailyCap = 10
}

extension PlayerProgress {
    /// Bir ipucu harcar. Bakiye yoksa false.
    public mutating func spendHint() -> Bool {
        guard hintBalance > 0 else { return false }
        hintBalance -= 1
        return true
    }

    /// Consumable satın alma işlemini bir kez uygular. Aynı işlem tekrar gelirse (yeniden teslim,
    /// uygulama çökmesi sonrası `Transaction.updates`) hiçbir şey vermez ve 0 döner.
    @discardableResult
    public mutating func applyHintPurchase(transactionID: UInt64, hints: Int) -> Int {
        guard grantedTransactionIDs.insert(transactionID).inserted else { return 0 }
        hintBalance += hints
        return hints
    }

    /// Tam Oyun bonusunu yalnız ilk kez verir (geri yükleme veya yeniden yükleme tekrar vermez).
    @discardableResult
    public mutating func grantFullGameBonusIfNeeded() -> Int {
        guard !fullGameBonusGranted else { return 0 }
        fullGameBonusGranted = true
        hintBalance += HintEconomy.fullGameBonus
        return HintEconomy.fullGameBonus
    }
}
