import GoogleMobileAds
import UIKit

/// Google AdMob uygulaması. Ödül yalnız `userDidEarnRewardHandler` geri çağrısında verilir; her gösterim
/// kendi bayrağını taşıdığı için ödül iki kez sayılamaz.
@MainActor
final class AdMobAdService: NSObject, AdService, FullScreenContentDelegate {
    private let configuration: AdsConfiguration
    private var rewarded: RewardedAd?
    private var interstitial: InterstitialAd?
    private var started = false
    private var dismissal: CheckedContinuation<Void, Never>?

    private(set) var isRewardedReady = false
    private(set) var isInterstitialReady = false

    init(configuration: AdsConfiguration = .current) {
        self.configuration = configuration
    }

    func start() async {
        guard !started else { return }
        started = true
        MobileAds.shared.requestConfiguration.maxAdContentRating = .general
        _ = await MobileAds.shared.start()
        await loadRewarded()
        await loadInterstitial()
    }

    private func loadRewarded() async {
        rewarded = try? await RewardedAd.load(with: configuration.rewardedUnitID, request: Request())
        rewarded?.fullScreenContentDelegate = self
        isRewardedReady = rewarded != nil
    }

    private func loadInterstitial() async {
        interstitial = try? await InterstitialAd.load(with: configuration.interstitialUnitID, request: Request())
        interstitial?.fullScreenContentDelegate = self
        isInterstitialReady = interstitial != nil
    }

    func showRewarded() async -> Bool {
        guard let ad = rewarded, let root = UIApplication.shared.topViewController else { return false }
        rewarded = nil
        isRewardedReady = false
        final class Earned { var value = false }
        let earned = Earned()
        await withCheckedContinuation { continuation in
            dismissal = continuation
            ad.present(from: root) { earned.value = true }
        }
        Task { await loadRewarded() }
        return earned.value
    }

    func showInterstitial() async -> Bool {
        guard let ad = interstitial, let root = UIApplication.shared.topViewController else { return false }
        interstitial = nil
        isInterstitialReady = false
        await withCheckedContinuation { continuation in
            dismissal = continuation
            ad.present(from: root)
        }
        Task { await loadInterstitial() }
        return true
    }

    // MARK: FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        finishPresentation()
    }

    private func finishPresentation() {
        dismissal?.resume()
        dismissal = nil
    }
}
