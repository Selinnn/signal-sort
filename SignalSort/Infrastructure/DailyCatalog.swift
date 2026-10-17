import Foundation
import GameCore

/// Gömülü günlük bulmacalar (`dailies.json`, `signalsort-cli build-dailies` ile üretilir).
struct DailyCatalog {
    let pack: DailyPack?

    func level(for day: DayKey) -> LevelDefinition? { pack?.level(for: day) }

    static let bundled: DailyCatalog = {
        guard let url = Bundle.main.url(forResource: "dailies", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let pack = try? JSONDecoder().decode(DailyPack.self, from: data) else {
            assertionFailure("dailies.json okunamadı")
            return DailyCatalog(pack: nil)
        }
        return DailyCatalog(pack: pack)
    }()
}

extension DayKey {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// Cihazın yerel günü, kullanıcının takvimi ne olursa olsun Gregoryen.
    static func today(now: Date = Date()) -> DayKey {
        #if DEBUG
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-dailyDate"),
           index + 1 < ProcessInfo.processInfo.arguments.count,
           let fixed = DayKey(ProcessInfo.processInfo.arguments[index + 1]) {
            return fixed
        }
        #endif
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return DayKey(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    var date: Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    var localizedText: String { date.formatted(date: .abbreviated, time: .omitted) }
}
