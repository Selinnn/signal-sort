/// Reklam sıklığı durumu (cihaza özel, ilerlemeden ayrı saklanır). Zaman saniye cinsinden dışarıdan verilir.
public struct AdPolicyState: Codable, Hashable, Sendable {
    /// Uygulamanın kaçıncı açılışı (ilk oturum = 1).
    public var sessionCount: Int
    /// Son geçiş reklamından (veya hiç yoksa baştan) beri tamamlanan kampanya seviyesi.
    public var levelsSinceInterstitial: Int
    public var lastInterstitialAt: Double?
    /// Gün → izlenen ödüllü reklam sayısı (yalnız son günler tutulur).
    public var rewardedByDay: [String: Int]

    public init(sessionCount: Int = 0, levelsSinceInterstitial: Int = 0, lastInterstitialAt: Double? = nil, rewardedByDay: [String: Int] = [:]) {
        self.sessionCount = sessionCount
        self.levelsSinceInterstitial = levelsSinceInterstitial
        self.lastInterstitialAt = lastInterstitialAt
        self.rewardedByDay = rewardedByDay
    }
}

/// Geçiş reklamının gösterilebileceği an: yalnız kampanyada Sonuç → "Sonraki" (PLAN §3.3).
public struct InterstitialContext: Sendable {
    /// Oyuncunun toplam tamamladığı kampanya seviyesi.
    public var completedCampaignLevels: Int
    public var hasRemoveAds: Bool
    /// Az önce biten oyun günlük bulmaca mıydı.
    public var cameFromDaily: Bool
    /// Mağaza veya başka bir sayfa açık mı.
    public var isOverlayPresented: Bool
    public var now: Double

    public init(completedCampaignLevels: Int, hasRemoveAds: Bool, cameFromDaily: Bool = false, isOverlayPresented: Bool = false, now: Double) {
        self.completedCampaignLevels = completedCampaignLevels
        self.hasRemoveAds = hasRemoveAds
        self.cameFromDaily = cameFromDaily
        self.isOverlayPresented = isOverlayPresented
        self.now = now
    }
}

/// Reklam kuralları (PLAN §3.3). Saf ve deterministik; AdMob yalnız bu kurallar izin verince çağrılır.
/// Ek emniyet olarak AdMob panelinde ad unit sıklık sınırı da kullanılır.
public struct AdPolicy: Sendable {
    public var minimumCompletedLevels = 10
    public var levelsBetweenInterstitials = 3
    public var secondsBetweenInterstitials: Double = 180
    public var rewardedDailyCap = HintEconomy.rewardedAdDailyCap

    public init() {}

    public func shouldShowInterstitial(_ state: AdPolicyState, _ context: InterstitialContext) -> Bool {
        if context.hasRemoveAds || context.cameFromDaily || context.isOverlayPresented { return false }
        if state.sessionCount <= 1 { return false }
        if context.completedCampaignLevels < minimumCompletedLevels { return false }
        if state.levelsSinceInterstitial < levelsBetweenInterstitials { return false }
        if let last = state.lastInterstitialAt, context.now - last < secondsBetweenInterstitials { return false }
        return true
    }

    public func canOfferRewarded(_ state: AdPolicyState, day: DayKey) -> Bool {
        (state.rewardedByDay[day.description] ?? 0) < rewardedDailyCap
    }
}

extension AdPolicyState {
    public mutating func recordLaunch() { sessionCount += 1 }

    public mutating func recordCampaignLevelCompleted() { levelsSinceInterstitial += 1 }

    public mutating func recordInterstitialShown(at now: Double) {
        levelsSinceInterstitial = 0
        lastInterstitialAt = now
    }

    /// Ödüllü reklam sayısını artırır ve bir haftadan eski günleri atar.
    public mutating func recordRewarded(day: DayKey) {
        rewardedByDay[day.description, default: 0] += 1
        rewardedByDay = rewardedByDay.filter { key, _ in DayKey(key).map { day.dayNumber - $0.dayNumber < 7 } ?? false }
    }
}
