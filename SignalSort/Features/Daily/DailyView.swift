import GameCore
import SwiftUI

/// Günlük bulmaca: bugünün kartı, nazik seri ve son 7 günün arşivi.
struct DailyView: View {
    let store: ProgressStore
    let today: DayKey
    @Binding var path: [AppRoute]

    var body: some View {
        let streak = store.dailyStreak(today: today)
        ScrollView {
            VStack(spacing: 16) {
                Label {
                    Text("daily.streak \(streak)")
                } icon: {
                    Image(systemName: "flame.fill").foregroundStyle(streak > 0 ? Color.accentColor : Theme.textSecondary)
                }
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)
                .accessibilityIdentifier("daily.streak")
                .padding(.top, 8)

                // Arşiv son 7 gün; paket başlangıcından önceki (döngüyle tekrar eden) günler gösterilmez.
                ForEach(archiveDays, id: \.self) { day in
                    dayRow(day, isToday: day == today)
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(Text("home.daily"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private var archiveDays: [DayKey] {
        let start = store.dailies.pack?.startDate
        return (0..<7).map { today.adding(days: -$0) }.filter { day in
            day == today || start.map { $0 <= day } ?? true
        }
    }

    private func dayRow(_ day: DayKey, isToday: Bool) -> some View {
        let record = store.progress.dailyRecords[day]
        return Button { path.append(.dailyLevel(day)) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isToday ? String(localized: "daily.today") : day.localizedText)
                        .font(isToday ? .title3.bold() : .headline)
                        .foregroundStyle(Theme.textPrimary)
                    if isToday {
                        Text(day.localizedText).font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                if let record {
                    StarsView(stars: record.stars, size: 14)
                } else {
                    Text("daily.notPlayed").font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
                Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
            }
            .padding(isToday ? 20 : 16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(isToday ? Color.accentColor : .clear, lineWidth: 2)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("daily.\(day)")
    }
}

struct StarsView: View {
    let stars: Int
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...3, id: \.self) { i in
                Image(systemName: i <= stars ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i <= stars ? Theme.hint : Theme.textSecondary.opacity(0.4))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("result.stars \(stars)"))
    }
}

/// Spoiler'sız paylaşım metni: yıldızlar, hamle/par ve Run denemeleri (🟥 başarısız, 🟩 çözüm).
enum DailyShare {
    static func text(day: DayKey, session: PlaySession) -> String {
        let stars = session.stars ?? 0
        let starText = String(repeating: "★", count: stars) + String(repeating: "☆", count: 3 - stars)
        let runs = String(repeating: "🟥", count: max(session.runCount - 1, 0)) + "🟩"
        let hints = session.hintsUsed > 0 ? " 💡\(session.hintsUsed)" : ""
        var lines = [String(localized: "share.title \(day.localizedText)")]
        if let par = session.par {
            lines.append("\(starText) · " + String(localized: "result.moves \(session.moves) \(par)"))
        }
        lines.append(runs + hints)
        return lines.joined(separator: "\n")
    }
}
