import GameCore
import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Signal Sort")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("home.title")
            Text("home.subtitle")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.accentColor.opacity(0.08))
    }
}

#Preview {
    HomeView()
}
