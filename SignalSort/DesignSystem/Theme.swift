import GameCore
import Observation
import SwiftUI

/// Tahta ve arayüz renk paleti. Sinyal renkleri temadan bağımsızdır (renk körü güvenli Okabe–Ito, PLAN §4).
struct Palette: Equatable {
    var colorScheme: ColorScheme
    var background: Color
    var surface: Color
    var cell: Color
    var cellBorder: Color
    var blocker: Color
    var arrow: Color
    var fixedArrow: Color
    var textPrimary: Color
    var textSecondary: Color
    /// Açık zeminde sarı gibi renklerin seçilebilmesi için şekil kenarı.
    var glyphOutline: Color
}

enum ThemeID: String, CaseIterable, Identifiable {
    case midnight, daylight, ember, forest, ocean

    var id: String { rawValue }

    /// Tam Oyun ile açılan temalar (mağaza vaadi: "ek tahta temaları").
    var isPremium: Bool {
        switch self {
        case .midnight, .daylight: false
        case .ember, .forest, .ocean: true
        }
    }

    var palette: Palette {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        let darkText = rgb(0.08, 0.09, 0.14)
        switch self {
        case .midnight:
            return Palette(colorScheme: .dark, background: rgb(0.06, 0.08, 0.16), surface: rgb(0.10, 0.13, 0.24),
                           cell: rgb(0.13, 0.17, 0.30), cellBorder: .white.opacity(0.06), blocker: rgb(0.04, 0.05, 0.10),
                           arrow: .white.opacity(0.92), fixedArrow: .white.opacity(0.45), textPrimary: .white,
                           textSecondary: .white.opacity(0.6), glyphOutline: .clear)
        case .daylight:
            return Palette(colorScheme: .light, background: rgb(0.94, 0.95, 0.97), surface: .white,
                           cell: rgb(0.86, 0.89, 0.94), cellBorder: .black.opacity(0.06), blocker: rgb(0.47, 0.51, 0.60),
                           arrow: darkText, fixedArrow: darkText.opacity(0.4), textPrimary: darkText,
                           textSecondary: darkText.opacity(0.6), glyphOutline: darkText.opacity(0.7))
        case .ember:
            return Palette(colorScheme: .dark, background: rgb(0.12, 0.06, 0.06), surface: rgb(0.20, 0.10, 0.09),
                           cell: rgb(0.28, 0.14, 0.12), cellBorder: .white.opacity(0.06), blocker: rgb(0.07, 0.03, 0.03),
                           arrow: .white.opacity(0.92), fixedArrow: .white.opacity(0.45), textPrimary: .white,
                           textSecondary: .white.opacity(0.6), glyphOutline: .clear)
        case .forest:
            return Palette(colorScheme: .dark, background: rgb(0.04, 0.11, 0.09), surface: rgb(0.07, 0.18, 0.14),
                           cell: rgb(0.10, 0.24, 0.19), cellBorder: .white.opacity(0.06), blocker: rgb(0.02, 0.06, 0.05),
                           arrow: .white.opacity(0.92), fixedArrow: .white.opacity(0.45), textPrimary: .white,
                           textSecondary: .white.opacity(0.6), glyphOutline: .clear)
        case .ocean:
            return Palette(colorScheme: .dark, background: rgb(0.03, 0.09, 0.15), surface: rgb(0.05, 0.15, 0.24),
                           cell: rgb(0.07, 0.21, 0.32), cellBorder: .white.opacity(0.07), blocker: rgb(0.01, 0.05, 0.09),
                           arrow: .white.opacity(0.92), fixedArrow: .white.opacity(0.45), textPrimary: .white,
                           textSecondary: .white.opacity(0.6), glyphOutline: .clear)
        }
    }

    var localizedName: String {
        switch self {
        case .midnight: String(localized: "theme.midnight")
        case .daylight: String(localized: "theme.daylight")
        case .ember: String(localized: "theme.ember")
        case .forest: String(localized: "theme.forest")
        case .ocean: String(localized: "theme.ocean")
        }
    }
}

/// Seçili tema. Tam Oyun hakkı kalkarsa (iade) premium tema seçimi korunur ama ücretsiz temaya düşülür.
@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()
    static let storageKey = "theme"

    var selection: ThemeID {
        didSet { UserDefaults.standard.set(selection.rawValue, forKey: Self.storageKey) }
    }
    var fullGameUnlocked = false

    private init() {
        selection = UserDefaults.standard.string(forKey: Self.storageKey).flatMap(ThemeID.init) ?? .midnight
    }

    var effective: ThemeID { selection.isPremium && !fullGameUnlocked ? .midnight : selection }
    var palette: Palette { effective.palette }
}

/// Görsel dil (PLAN §4). Değerler seçili temadan okunur; görünümler bunlara eriştiği için tema değişince yenilenir.
@MainActor
enum Theme {
    static var palette: Palette { ThemeManager.shared.palette }
    static var colorScheme: ColorScheme { palette.colorScheme }
    static var background: Color { palette.background }
    static var surface: Color { palette.surface }
    static var cell: Color { palette.cell }
    static var cellBorder: Color { palette.cellBorder }
    static var blocker: Color { palette.blocker }
    static var arrow: Color { palette.arrow }
    static var fixedArrow: Color { palette.fixedArrow }
    static var textPrimary: Color { palette.textPrimary }
    static var textSecondary: Color { palette.textSecondary }
    static var glyphOutline: Color { palette.glyphOutline }

    /// Vurgu rengi (turuncu) üzerindeki yazı; her temada koyu kalır.
    static let onAccent = Color(red: 0.06, green: 0.08, blue: 0.16)
    static let failure = Color(red: 0.95, green: 0.30, blue: 0.30)
    static let success = Color(red: 0.25, green: 0.75, blue: 0.48)
    static let hint = Color(red: 1.0, green: 0.80, blue: 0.25)
}

extension SignalColor {
    var color: Color {
        switch self {
        case .orange: Color(red: 0.902, green: 0.624, blue: 0.000)
        case .blue: Color(red: 0.337, green: 0.706, blue: 0.914)
        case .green: Color(red: 0.000, green: 0.620, blue: 0.451)
        case .yellow: Color(red: 0.941, green: 0.894, blue: 0.259)
        case .pink: Color(red: 0.800, green: 0.475, blue: 0.655)
        }
    }

    var localizedName: String {
        switch self {
        case .orange: String(localized: "color.orange")
        case .blue: String(localized: "color.blue")
        case .green: String(localized: "color.green")
        case .yellow: String(localized: "color.yellow")
        case .pink: String(localized: "color.pink")
        }
    }
}

extension Direction {
    /// Yukarıyı gösteren bir şeklin bu yöne bakması için gereken açı.
    var degrees: Double { Double(clockwiseSteps(from: .north)) * 90 }

    var localizedName: String {
        switch self {
        case .north: String(localized: "direction.north")
        case .east: String(localized: "direction.east")
        case .south: String(localized: "direction.south")
        case .west: String(localized: "direction.west")
        }
    }
}
