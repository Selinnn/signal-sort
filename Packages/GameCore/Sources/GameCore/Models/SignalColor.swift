/// Okabe–Ito tabanlı, renk körü güvenli sinyal renkleri. Her rengin bir şekil karşılığı vardır (PLAN §4).
public enum SignalColor: String, Codable, CaseIterable, Sendable {
    case orange, blue, green, yellow, pink
}
