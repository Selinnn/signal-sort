import GameCore
import SwiftUI

/// Geçici ana ekran: seviye listesi. Asıl Home ve bölüm haritası adım 8'de gelir.
struct HomeView: View {
    let catalog: LevelCatalog
    @State private var path: [Int] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(catalog.levels.indices, id: \.self) { index in
                        NavigationLink(value: index) {
                            HStack {
                                Text("board.level \(index + 1)")
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text(catalog.levels[index].id)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .listRowBackground(Theme.surface)
                        .accessibilityIdentifier("level.\(index)")
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Signal Sort")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Theme.textPrimary)
                            .accessibilityIdentifier("home.title")
                        Text("home.subtitle")
                            .font(.headline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .textCase(nil)
                    .padding(.bottom, 12)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationDestination(for: Int.self) { index in
                BoardScreen(
                    level: catalog.levels[index],
                    number: index + 1,
                    onNext: index + 1 < catalog.levels.count ? { path.append(index + 1) } : nil)
                .id(index)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    HomeView(catalog: .bundled)
}
