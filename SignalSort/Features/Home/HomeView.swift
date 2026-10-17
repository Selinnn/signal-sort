import GameCore
import SwiftUI

struct HomeView: View {
    let store: ProgressStore
    let today: DayKey
    @Binding var path: [AppRoute]
    let showStore: () -> Void

    var body: some View {
        // Büyük yazı boyutlarında içerik kaydırılabilir; normal boyutta ekranı doldurur ve düğmeler altta kalır.
        GeometryReader { geometry in
            ScrollView {
                content
                    .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var content: some View {
        VStack(spacing: 28) {
            topBar
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Text("Signal Sort")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityIdentifier("home.title")
                Text("home.subtitle")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 10) {
                ForEach(SignalColor.allCases.prefix(4), id: \.self) { color in
                    SignalGlyph(color: color).frame(width: 22, height: 22)
                }
            }
            .accessibilityHidden(true)
            Spacer(minLength: 0)
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
        .frame(maxWidth: .infinity)
    }

    private var topBar: some View {
        HStack {
            Button { path.append(.settings) } label: { circleIcon("gearshape.fill") }
                .accessibilityLabel(Text("settings.title"))
                .accessibilityIdentifier("home.settings")
            Spacer()
            Button(action: showStore) { circleIcon("bag.fill") }
                .accessibilityLabel(Text("store.title"))
                .accessibilityIdentifier("home.store")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func circleIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.title3)
            .frame(width: 48, height: 48)
            .background(Circle().fill(Theme.surface))
            .foregroundStyle(Theme.textPrimary)
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
                .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if streak > 0 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Color.accentColor)
                }
                if let record { StarsView(stars: record.stars) }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
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
                .foregroundStyle(Theme.onAccent)
            }
            .accessibilityIdentifier("home.continue")
        } else if store.isWaitingForFullGame {
            Button(action: showStore) {
                Label("home.unlockFullGame", systemImage: "lock.open.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.accentColor))
                    .foregroundStyle(Theme.onAccent)
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
