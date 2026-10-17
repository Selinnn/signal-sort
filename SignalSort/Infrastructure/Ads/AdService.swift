import Foundation
import UIKit

/// Oyun kodu reklam ağını yalnız bu protokolden görür (PLAN §5). Testlerde ve önizlemede `MockAdService`.
@MainActor
protocol AdService: AnyObject {
    var isRewardedReady: Bool { get }
    var isInterstitialReady: Bool { get }
    /// SDK'yı başlatır ve reklamları önceden yükler. Onay alınmadan çağrılmaz.
    func start() async
    /// Ödüllü reklamı gösterir; yalnız ağın ödül geri çağrısı geldiyse true. Hazır değilse beklemeden false.
    func showRewarded() async -> Bool
    /// Geçiş reklamını gösterir ve kapanana kadar bekler; gösterildiyse true.
    func showInterstitial() async -> Bool
}

/// Info.plist'teki reklam kimlikleri (Debug: Google test kimlikleri, Release: gerçek kimlikler).
struct AdsConfiguration {
    let rewardedUnitID: String
    let interstitialUnitID: String

    static let current = AdsConfiguration(
        rewardedUnitID: Bundle.main.object(forInfoDictionaryKey: "SignalSortRewardedAdUnitID") as? String ?? "",
        interstitialUnitID: Bundle.main.object(forInfoDictionaryKey: "SignalSortInterstitialAdUnitID") as? String ?? "")
}

extension UIApplication {
    /// Tam ekran reklam ve onay formu için en üstteki görünüm denetleyicisi.
    var topViewController: UIViewController? {
        let window = connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow)
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
