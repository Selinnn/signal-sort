import AppTrackingTransparency
import Observation
import UIKit
import UserMessagingPlatform

/// Reklam onayı sırası (PLAN §3.3): ilk açılışta hiçbir şey istenmez. Tutorial bitince (veya ilk ödüllü reklam
/// isteğinde) önce Google UMP onay formu (yalnız gereken bölgelerde), sonra kısa açıklamanın ardından ATT izni.
/// Reddedilirse kişiselleştirilmemiş reklam gösterilir; oyun aynı çalışır.
@MainActor
@Observable
final class ConsentManager {
    /// UI testlerinde UMP ve ATT atlanır.
    let isMock: Bool
    private(set) var hasGathered = false
    /// ATT için uygulama içi açıklama gösterilmeli mi (RootView sayfa olarak gösterir).
    var showsTrackingExplainer = false

    init(isMock: Bool) {
        self.isMock = isMock
    }

    var canRequestAds: Bool { isMock || ConsentInformation.shared.canRequestAds }

    var isPrivacyOptionsRequired: Bool {
        !isMock && ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    /// UMP bilgisini günceller, gerekiyorsa formu gösterir; ardından ATT kararı verilmemişse açıklamayı ister.
    func gather() async {
        guard !hasGathered else { return }
        defer { hasGathered = true }
        if isMock { return }
        let parameters = RequestParameters()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-umpDebugEEA") {
            let debug = DebugSettings()
            debug.geography = .EEA
            parameters.debugSettings = debug
        }
        #endif
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            try await ConsentForm.loadAndPresentIfRequired(from: UIApplication.shared.topViewController)
        } catch {
            // Ağ yoksa veya form yüklenemezse sonraki denemede tekrar sorulur; oyun etkilenmez.
            return
        }
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            showsTrackingExplainer = true
        }
    }

    /// Açıklama ekranındaki "Devam" düğmesinden sonra sistem ATT penceresi.
    func requestTracking() async {
        showsTrackingExplainer = false
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    /// Ayarlar'daki "Gizlilik seçenekleri" (UMP zorunlu tutar).
    func presentPrivacyOptions() async {
        guard !isMock else { return }
        try? await ConsentForm.presentPrivacyOptionsForm(from: UIApplication.shared.topViewController)
    }
}
