import GameCore
import SwiftUI

extension Chapter {
    var localizedName: String {
        switch id {
        case "route": String(localized: "chapter.route")
        case "obstacle": String(localized: "chapter.obstacle")
        case "crossing": String(localized: "chapter.crossing")
        case "color": String(localized: "chapter.color")
        case "toggle": String(localized: "chapter.toggle")
        default: String(localized: "chapter.master")
        }
    }
}

/// Bölüm haritası: her bölümün ilerlemesi, yıldızları ve kilit nedeni.
struct ChapterMapView: View {
    let store: ProgressStore
    @Binding var path: [AppRoute]
    let showStore: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(store.catalog.chapters.indices, id: \.self) { index in
                    chapterCard(index)
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(Text("home.chapters"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private func chapterCard(_ index: Int) -> some View {
        let chapter = store.catalog.chapters[index]
        let availability = store.chapterAvailability(index)
        let completed = store.progression.completedCount(chapter: index, progress: store.progress)
        let stars = store.progression.stars(chapter: index, progress: store.progress)
        let locked = availability != .available

        return Button {
            if availability == .requiresFullGame { showStore() } else { path.append(.chapter(index)) }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Theme.cell).frame(width: 52, height: 52)
                    if locked {
                        Image(systemName: availability == .requiresFullGame ? "crown.fill" : "lock.fill")
                            .foregroundStyle(availability == .requiresFullGame ? Theme.hint : Theme.textSecondary)
                    } else {
                        Text("\(index + 1)").font(.title2.bold()).foregroundStyle(Theme.textPrimary)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("chapter.title \(index + 1)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text(chapter.localizedName)
                        .font(.title3.bold())
                        .foregroundStyle(locked ? Theme.textSecondary : Theme.textPrimary)
                    Group {
                        switch availability {
                        case .available: Text("chapter.progress \(completed) \(chapter.levels.count)")
                        case .lockedByProgress: Text("chapter.lockedProgress \(index)")
                        case .requiresFullGame: Text("chapter.lockedFullGame")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if !locked {
                    Label("\(stars)", systemImage: "star.fill")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.hint)
                        .labelStyle(.titleAndIcon)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface))
        }
        .buttonStyle(.plain)
        .disabled(availability == .lockedByProgress)
        .accessibilityIdentifier("chapter.\(index)")
    }
}

/// Bir bölümün seviyeleri: numara, yıldızlar, kilit.
struct ChapterLevelsView: View {
    let store: ProgressStore
    let chapterIndex: Int
    @Binding var path: [AppRoute]

    var body: some View {
        let chapter = store.catalog.chapters[chapterIndex]
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(chapter.levels, id: \.id) { level in
                    levelButton(level)
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(Text(chapter.localizedName))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private func levelButton(_ level: LevelDefinition) -> some View {
        let locked = store.availability(of: level.id) != .available
        let stars = store.progress.stars(level.id)
        let number = store.catalog.number(of: level.id)
        let isNext = store.continueLevel?.id == level.id

        return Button { path.append(.level(level.id)) } label: {
            VStack(spacing: 4) {
                if locked {
                    Image(systemName: "lock.fill").font(.headline).foregroundStyle(Theme.textSecondary.opacity(0.6))
                } else {
                    Text("\(number)").font(.headline.monospacedDigit()).foregroundStyle(Theme.textPrimary)
                }
                HStack(spacing: 1) {
                    ForEach(1...3, id: \.self) { i in
                        Image(systemName: i <= stars ? "star.fill" : "star")
                            .font(.system(size: 8))
                            .foregroundStyle(i <= stars ? Theme.hint : Theme.textSecondary.opacity(0.35))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(locked ? Theme.surface.opacity(0.5) : Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(isNext ? Color.accentColor : .clear, lineWidth: 2)))
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel(locked ? Text("level.locked \(number)") : Text("level.a11y \(number) \(stars)"))
        .accessibilityIdentifier("level.\(level.id)")
    }
}
