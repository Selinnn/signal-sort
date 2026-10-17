import Observation
import SwiftUI

/// UI testleri ve önizleme için sahte reklam: tam ekran bir katman gösterir; ödül yalnız "ödülü al" ile verilir.
@MainActor
@Observable
final class MockAdService: AdService {
    enum Presentation: Equatable { case rewarded, interstitial }

    private(set) var presenting: Presentation?
    private(set) var interstitialsShown = 0
    var isRewardedReady = true
    var isInterstitialReady = true
    @ObservationIgnored private var completion: CheckedContinuation<Bool, Never>?

    func start() async {}

    func showRewarded() async -> Bool {
        guard isRewardedReady else { return false }
        return await present(.rewarded)
    }

    func showInterstitial() async -> Bool {
        guard isInterstitialReady else { return false }
        interstitialsShown += 1
        _ = await present(.interstitial)
        return true
    }

    /// Katmandaki düğmeler: ödüllü reklamda `rewarded: true` ödülü verir, kapatmak vermez.
    func finish(rewarded: Bool) {
        presenting = nil
        completion?.resume(returning: rewarded)
        completion = nil
    }

    private func present(_ kind: Presentation) async -> Bool {
        await withCheckedContinuation { continuation in
            completion = continuation
            presenting = kind
        }
    }
}

struct MockAdOverlay: View {
    let service: MockAdService

    var body: some View {
        if let presenting = service.presenting {
            VStack(spacing: 20) {
                Text(presenting == .rewarded ? "Mock rewarded ad" : "Mock interstitial ad")
                    .font(.title2.bold())
                    .accessibilityIdentifier(presenting == .rewarded ? "mockAd.rewarded" : "mockAd.interstitial")
                if presenting == .rewarded {
                    Button("Claim reward") { service.finish(rewarded: true) }
                        .accessibilityIdentifier("mockAd.claim")
                }
                Button("Close") { service.finish(rewarded: false) }
                    .accessibilityIdentifier("mockAd.close")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.ignoresSafeArea())
        }
    }
}
