/// Takvim günü (Gregoryen, saat dilimsiz). Günlük bulmacanın anahtarı: cihazın yerel günü (PLAN §1.9).
/// Foundation'a bağlı değildir; gün sayısı Howard Hinnant'ın `days_from_civil` algoritmasıyla hesaplanır.
public struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// "yyyy-MM-dd". Geçersiz tarih (ör. 2026-02-30) nil.
    public init?(_ text: String) {
        let parts = text.split(separator: "-").map { Int($0) }
        guard parts.count == 3, let y = parts[0], let m = parts[1], let d = parts[2], (1...12).contains(m), d >= 1 else { return nil }
        let candidate = DayKey(year: y, month: m, day: d)
        guard DayKey(dayNumber: candidate.dayNumber) == candidate else { return nil }
        self = candidate
    }

    /// 1970-01-01'den beri gün sayısı.
    public var dayNumber: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    public init(dayNumber: Int) {
        let z = dayNumber + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        self.init(year: yoe + era * 400 + (m <= 2 ? 1 : 0), month: m, day: d)
    }

    public func adding(days: Int) -> DayKey { DayKey(dayNumber: dayNumber + days) }

    /// ISO hafta günü: 1 = Pazartesi … 7 = Pazar.
    public var isoWeekday: Int { ((dayNumber + 3) % 7 + 7) % 7 + 1 }

    public var description: String {
        func pad(_ n: Int, _ width: Int) -> String {
            let s = String(n)
            return String(repeating: "0", count: max(0, width - s.count)) + s
        }
        return "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))"
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.dayNumber < rhs.dayNumber }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let key = DayKey(text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Geçersiz tarih: \(text)"))
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
