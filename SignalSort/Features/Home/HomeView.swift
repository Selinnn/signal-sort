import GameCore
import SwiftUI

struct HomeView: View {
    let store: ProgressStore
    let today: DayKey
    @Binding var path: [AppRoute]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 8) {
                Text("Signal Sort")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityIdentifier("home.title")
                Text("home.subtitle")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 10) {
                ForEach(SignalColor.allCases.prefix(4), id: \.self) { color in
                    SignalGlyph(color: color).frame(width: 22, height: 22)
                }
            }
            .accessibilityHidden(true)
            Spacer()
            VStack(spacing: 14) {
                primaryButton
                dailyButton
                Button { path.append(.chapters) } label: {
                    Label("home.chapters", systemImage: "square.grid.3x3.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface))
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityIdentifier("home.chapters")
                Label {
                    Text("home.stars \(store.totalStars) \(store.maxStars)")
                } icon: {
                    Image(systemName: "star.fill").foregroundStyle(Theme.hint)
                }
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .accessibilityIdentifier("home.stars")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var dailyButton: some View {
        let record = store.progress.dailyRecords[today]
        let streak = store.dailyStreak(today: today)
        return Button { path.append(.daily) } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar").font(.title3).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("home.daily").font(.headline).foregroundStyle(Theme.textPrimary)
                    Text(record == nil ? String(localized: "home.dailyNew") : String(localized: "home.dailySolved"))
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if streak > 0 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Color.accentColor)
                }
                if let record { StarsView(stars: record.stars) }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.daily")
    }

    @ViewBuilder
    private var primaryButton: some View {
        if let level = store.continueLevel {
            let number = store.catalog.number(of: level.id)
            Button { path.append(.level(level.id)) } label: {
                Group {
                    if store.progress.records.isEmpty { Text("home.play") } else { Text("home.continue \(number)") }
                }
                .font(.title3.bold())
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.accentColor))
                .foregroundStyle(Theme.background)
            }
            .accessibilityIdentifier("home.continue")
        } else if store.isWaitingForFullGame {
            Button { path.append(.chapters) } label: {
                Label("home.unlockFullGame", systemImage: "lock.open.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.accentColor))
                    .foregroundStyle(Theme.background)
            }
            .accessibilityIdentifier("home.unlock")
        } else {
            Text("home.allComplete")
                .font(.title3.bold())
                .foregroundStyle(Theme.success)
                .frame(maxWidth: .infinity, minHeight: 64)
                .accessibilityIdentifier("home.allComplete")
        }
    }
}
