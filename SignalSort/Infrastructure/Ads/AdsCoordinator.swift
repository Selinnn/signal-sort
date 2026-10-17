import Foundation
import GameCore
import Observation

/// Reklam kurallarını (`AdPolicy`), onayı ve reklam ağını bir araya getirir. Sıklık durumu cihazda ayrı saklanır.
@MainActor
@Observable
final class AdsCoordinator {
    static let storageKey = "adPolicyState"

    let service: AdService
    let consent: ConsentManager
    private let policy = AdPolicy()
    private(set) var state: AdPolicyState
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var started = false

    init(service: AdService, consent: ConsentManager, defaults: UserDefaults = .standard) {
        self.service = service
        self.consent = consent
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey), let stored = try? JSONDecoder().decode(AdPolicyState.self, from: data) {
            state = stored
        } else {
            state = AdPolicyState()
        }
    }

    func appLaunched() async {
        state.recordLaunch()
        save()
        // UMP önceki onayı saklar: daha önce alınmışsa SDK hemen başlar, yoksa tutorial sonuna kadar beklenir.
        if consent.canRequestAds { await startServiceIfNeeded() }
    }

    /// Tutorial bitince veya ilk ödüllü reklamda çağrılır.
    func ensureConsent() async {
        await consent.gather()
        if consent.canRequestAds { await startServiceIfNeeded() }
    }

    func canOfferRewarded(today: DayKey) -> Bool {
        policy.canOfferRewarded(state, day: today)
    }

    /// Ödüllü reklam izletir; ödül geldiyse ipucu verir ve true döner.
    func watchRewardedForHint(today: DayKey, progress: ProgressStore) async -> Bool {
        guard canOfferRewarded(today: today) else { return false }
        await ensureConsent()
        guard consent.canRequestAds, await service.showRewarded() else { return false }
        state.recordRewarded(day: today)
        save()
        progress.grantHints(HintEconomy.rewardedAdHints)
        return true
    }

    func campaignLevelCompleted() {
        state.recordCampaignLevelCompleted()
        save()
    }

    /// Kampanyada "Sonraki"ye basılınca; kurallar izin verir ve reklam hazırsa gösterir.
    func maybeShowInterstitial(completedCampaignLevels: Int, hasRemoveAds: Bool) async {
        let context = InterstitialContext(
            completedCampaignLevels: completedCampaignLevels, hasRemoveAds: hasRemoveAds, now: Date().timeIntervalSince1970)
        guard consent.canRequestAds, policy.shouldShowInterstitial(state, context), service.isInterstitialReady else { return }
        if await service.showInterstitial() {
            state.recordInterstitialShown(at: Date().timeIntervalSince1970)
            save()
        }
    }

    #if DEBUG
    func overrideState(_ newState: AdPolicyState) {
        state = newState
        save()
    }
    #endif

    private func startServiceIfNeeded() async {
        guard !started else { return }
        started = true
        await service.start()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: Self.storageKey) }
    }
}
