import GameCore
import StoreKit
import SwiftUI

/// Mağaza: Tam Oyun, Reklamları Kaldır, ipucu paketi ve geri yükleme.
struct StoreView: View {
    let shop: StoreService
    let store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchaseAction
    @State private var message: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Label {
                        Text("store.hintBalance \(store.hintBalance)")
                    } icon: {
                        Image(systemName: "lightbulb.fill").foregroundStyle(Theme.hint)
                    }
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityIdentifier("store.hintBalance")

                    card(.fullGame, symbol: "crown.fill", title: "store.fullGame.title",
                         features: ["store.fullGame.chapters", "store.fullGame.noAds", "store.fullGame.hints \(HintEconomy.fullGameBonus)", "store.fullGame.themes"],
                         owned: shop.hasFullGame, highlighted: true)
                    card(.removeAds, symbol: "nosign", title: "store.removeAds.title",
                         features: ["store.removeAds.detail", "store.removeAds.fullGameNote"],
                         owned: shop.hasRemoveAds, highlighted: false)
                    card(.hints10, symbol: "lightbulb.fill", title: "store.hints.title \(HintEconomy.packSize)",
                         features: ["store.hints.detail"], owned: false, highlighted: false)

                    if shop.products.isEmpty && !shop.isLoading {
                        Button { Task { await shop.loadProducts() } } label: {
                            Label("store.unavailable", systemImage: "arrow.clockwise")
                        }
                        .foregroundStyle(Theme.textSecondary)
                        .accessibilityIdentifier("store.retry")
                    }

                    Button {
                        Task {
                            await shop.restore()
                            message = "store.restored"
                        }
                    } label: {
                        Text("store.restore").font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 8)
                    .accessibilityIdentifier("store.restore")
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(Text("store.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("store.close") { dismiss() }.accessibilityIdentifier("store.close")
                }
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("store.ok", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }

    private func card(_ id: StoreService.ProductID, symbol: String, title: LocalizedStringKey,
                      features: [LocalizedStringKey], owned: Bool, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(features.indices, id: \.self) { index in
                    Label(features[index], systemImage: "checkmark")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Button {
                Task {
                    switch await shop.purchase(id, perform: { try await purchaseAction($0) }) {
                    case .purchased: message = "store.thanks"
                    case .pending: message = "store.pending"
                    case .failed: message = "store.failed"
                    case .cancelled: break
                    }
                }
            } label: {
                Group {
                    if owned {
                        Label("store.owned", systemImage: "checkmark.seal.fill")
                    } else if shop.purchasing == id {
                        ProgressView().tint(Theme.background)
                    } else if let product = shop.products[id] {
                        Text(product.displayPrice)
                    } else {
                        Text("—")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 14).fill(owned ? Theme.cell : (highlighted ? Color.accentColor : Theme.cell)))
                .foregroundStyle(owned || !highlighted ? Theme.textPrimary : Theme.background)
            }
            .disabled(owned || shop.products[id] == nil || shop.purchasing != nil)
            .accessibilityIdentifier("store.buy.\(id.rawValue.split(separator: ".").last!)")
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(highlighted ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1.5)))
    }
}
