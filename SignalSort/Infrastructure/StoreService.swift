import Foundation
import GameCore
import Observation
import StoreKit

/// StoreKit 2: ürünler, satın alma, geri yükleme ve hak doğrulama (PLAN §3.3).
/// Satın alma durumu yerel bayrağa değil her açılışta `Transaction.currentEntitlements`'a dayanır;
/// iade edilen Tam Oyun bir sonraki doğrulamada kilitlenir.
@MainActor
@Observable
final class StoreService {
    enum ProductID: String, CaseIterable {
        case fullGame = "com.selinkaplan.signalsort.fullgame"
        case removeAds = "com.selinkaplan.signalsort.removeads"
        case hints10 = "com.selinkaplan.signalsort.hints10"
    }

    enum PurchaseOutcome: Equatable {
        case purchased, pending, cancelled, failed
    }

    private(set) var products: [ProductID: Product] = [:]
    private(set) var ownedProductIDs: Set<String> = []
    private(set) var isLoading = false
    private(set) var purchasing: ProductID?

    @ObservationIgnored private let progress: ProgressStore
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    /// Bu oturumda doğrulanmış işlemlerden bilinen kalıcı ürün değişiklikleri. `currentEntitlements` bir kez
    /// okunduktan sonra yeni satın almayı geç yansıtabildiği için (StoreKit test ortamında gözlendi) hak listesi
    /// bunlarla birleştirilir; iade (`revocationDate`) gelince ürün düşülür.
    @ObservationIgnored private var confirmedPurchases: Set<String> = []
    @ObservationIgnored private var confirmedRevocations: Set<String> = []

    init(progress: ProgressStore) {
        self.progress = progress
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    var hasFullGame: Bool { ownedProductIDs.contains(ProductID.fullGame.rawValue) }
    /// Tam Oyun reklamsızlığı da içerir.
    var hasRemoveAds: Bool { hasFullGame || ownedProductIDs.contains(ProductID.removeAds.rawValue) }

    func start() async {
        await refreshEntitlements()
        await loadProducts()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        guard let loaded = try? await Product.products(for: ProductID.allCases.map(\.rawValue)) else { return }
        var map: [ProductID: Product] = [:]
        for product in loaded {
            if let id = ProductID(rawValue: product.id) { map[id] = product }
        }
        products = map
    }

    /// `perform`, satın almayı başlatır; arayüzde SwiftUI'nin `purchase` ortam eylemi verilir
    /// (pencere bağlamını o sağlar; bağlamsız `product.purchase()` iOS 26'da asılı kalabiliyor).
    func purchase(_ id: ProductID, perform: (Product) async throws -> Product.PurchaseResult) async -> PurchaseOutcome {
        guard let product = products[id], purchasing == nil else { return .failed }
        purchasing = id
        defer { purchasing = nil }
        do {
            switch try await perform(product) {
            case .success(let verification):
                guard await handle(verification) else { return .failed }
                return .purchased
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    /// "Satın alımları geri yükle" (Apple zorunlu tutar).
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                owned.insert(transaction.productID)
            }
        }
        ownedProductIDs = owned.union(confirmedPurchases).subtracting(confirmedRevocations)
        applyEntitlements()
    }

    /// Doğrulanmış işlemi uygular ve bitirir. Consumable ipuçları işlem ID'siyle bir kez verilir.
    @discardableResult
    private func handle(_ verification: VerificationResult<Transaction>) async -> Bool {
        guard case .verified(let transaction) = verification else { return false }
        await apply(transaction)
        return true
    }

    /// Doğrulanmış işlemi uygular ve bitirir. Aynı işlem birden çok kez gelse de ipucu bir kez verilir.
    func apply(_ transaction: Transaction) async {
        if transaction.productType == .consumable {
            if transaction.productID == ProductID.hints10.rawValue, transaction.revocationDate == nil {
                progress.applyHintPurchase(transactionID: transaction.id, hints: HintEconomy.packSize)
            }
        } else if transaction.revocationDate == nil {
            confirmedPurchases.insert(transaction.productID)
            confirmedRevocations.remove(transaction.productID)
        } else {
            confirmedPurchases.remove(transaction.productID)
            confirmedRevocations.insert(transaction.productID)
        }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func applyEntitlements() {
        progress.hasFullGame = hasFullGame
        progress.hasRemoveAds = hasRemoveAds
        ThemeManager.shared.fullGameUnlocked = hasFullGame || progress.unlockAll
        if hasFullGame { progress.grantFullGameBonusIfNeeded() }
    }
}
