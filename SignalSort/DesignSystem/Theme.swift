import GameCore
import SwiftUI

/// Görsel dil (PLAN §4): koyu lacivert zemin, Okabe–Ito renkleri, her rengin bir şekli.
enum Theme {
    static let background = Color(red: 0.06, green: 0.08, blue: 0.16)
    static let surface = Color(red: 0.10, green: 0.13, blue: 0.24)
    static let cell = Color(red: 0.13, green: 0.17, blue: 0.30)
    static let cellBorder = Color.white.opacity(0.06)
    static let blocker = Color(red: 0.04, green: 0.05, blue: 0.10)
    static let arrow = Color.white.opacity(0.92)
    static let fixedArrow = Color.white.opacity(0.45)
    static let failure = Color(red: 1.0, green: 0.33, blue: 0.33)
    static let success = Color(red: 0.35, green: 0.85, blue: 0.55)
    static let hint = Color(red: 1.0, green: 0.85, blue: 0.35)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
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
