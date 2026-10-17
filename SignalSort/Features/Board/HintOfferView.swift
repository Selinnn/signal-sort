import SwiftUI

/// İpucu bitince: isteğe bağlı ödüllü reklam (+1) veya mağaza. Reklam hazır değilse yalnız mağaza görünür.
struct HintOfferView: View {
    let canWatchAd: Bool
    let watchAd: () -> Void
    let openStore: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb.fill").font(.system(size: 40)).foregroundStyle(Theme.hint)
            Text("hintOffer.title").font(.title2.bold()).foregroundStyle(Theme.textPrimary)
            Text("hintOffer.body").font(.subheadline).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            if canWatchAd {
                Button(action: watchAd) {
                    Label("hintOffer.watchAd", systemImage: "play.rectangle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.accentColor))
                        .foregroundStyle(Theme.onAccent)
                }
                .accessibilityIdentifier("hintOffer.watchAd")
            }
            Button(action: openStore) {
                Label("hintOffer.store", systemImage: "bag.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cell))
                    .foregroundStyle(Theme.textPrimary)
            }
            .accessibilityIdentifier("hintOffer.store")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface.ignoresSafeArea())
        .preferredColorScheme(Theme.colorScheme)
    }
}

/// ATT sistem penceresinden önce kısa açıklama (PLAN §3.3).
struct TrackingExplainerView: View {
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "hand.raised.fill").font(.system(size: 44)).foregroundStyle(Color.accentColor)
            Text("tracking.title").font(.title2.bold()).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.center)
            Text("tracking.body").font(.body).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            Button {
                dismiss()
                onContinue()
            } label: {
                Text("tracking.continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.accentColor))
                    .foregroundStyle(Theme.onAccent)
            }
            .accessibilityIdentifier("tracking.continue")
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface.ignoresSafeArea())
        .interactiveDismissDisabled()
        .preferredColorScheme(Theme.colorScheme)
    }
}
