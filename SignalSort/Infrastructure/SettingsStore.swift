import Foundation
import Observation

/// Oyuncu ayarları (UserDefaults). Tema `ThemeManager`'dadır.
@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    var soundEnabled: Bool { didSet { save() } }
    var hapticsEnabled: Bool { didSet { save() } }
    /// Renk körlüğü desteği: şekillere belirgin kenar ve renkli oklarda büyük şekil.
    var strongShapes: Bool { didSet { save() } }
    /// Run animasyonu varsayılan olarak 2× başlasın mı.
    var fastPlayback: Bool { didSet { save() } }

    @ObservationIgnored private let defaults = UserDefaults.standard

    private init() {
        soundEnabled = defaults.object(forKey: "settings.sound") as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: "settings.haptics") as? Bool ?? true
        strongShapes = defaults.object(forKey: "settings.strongShapes") as? Bool ?? false
        fastPlayback = defaults.object(forKey: "settings.fastPlayback") as? Bool ?? false
    }

    func resetToDefaults() {
        soundEnabled = true
        hapticsEnabled = true
        strongShapes = false
        fastPlayback = false
    }

    private func save() {
        defaults.set(soundEnabled, forKey: "settings.sound")
        defaults.set(hapticsEnabled, forKey: "settings.haptics")
        defaults.set(strongShapes, forKey: "settings.strongShapes")
        defaults.set(fastPlayback, forKey: "settings.fastPlayback")
    }
}

/// Mağaza ve App Store için zorunlu bağlantılar (adım 13'te yayımlanır).
enum AppLinks {
    static let privacyPolicy = URL(string: "https://selinkaplan.github.io/signal-sort/privacy.html")!
    static let support = URL(string: "https://selinkaplan.github.io/signal-sort/support.html")!
}
