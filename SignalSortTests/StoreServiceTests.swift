import Foundation
import GameCore
import StoreKit
import StoreKitTest
import Testing
@testable import SignalSort

private final class BundleToken {}

/// StoreKit Configuration ile yerel satın alma testleri (PLAN §8 adım 10). Satın alma `SKTestSession.buyProduct`
/// ile yapılır (arayüzsüz `Product.purchase()` test ortamında asılı kalır); uygulamanın işlem mantığı
/// `StoreService.apply` ve `refreshEntitlements` ile sınanır.
@MainActor
@Suite(.serialized)
struct StoreServiceTests {
    let session: SKTestSession
    let progress: ProgressStore
    let shop: StoreService

    init() async throws {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "SignalSort", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        let defaults = try #require(UserDefaults(suiteName: "store-tests-\(UUID().uuidString)"))
        progress = ProgressStore(catalog: .bundled, dailies: .bundled, defaults: defaults)
        shop = StoreService(progress: progress)
        await shop.start()
    }

    @Test func loadsAllProducts() {
        #expect(Set(shop.products.keys) == Set(StoreService.ProductID.allCases))
        #expect(shop.products[.fullGame]?.displayPrice.contains("4.99") == true)
        #expect(!shop.hasFullGame && !shop.hasRemoveAds)
    }

    func buy(_ id: StoreService.ProductID) async throws -> Transaction {
        let transaction = try await session.buyProduct(identifier: id.rawValue)
        await shop.apply(transaction)
        return transaction
    }

    @Test func fullGameUnlocksChaptersRemovesAdsAndGrantsBonusOnce() async throws {
        #expect(progress.availability(of: "c4-01") == .requiresFullGame)
        let transaction = try await buy(.fullGame)
        #expect(shop.hasFullGame && shop.hasRemoveAds)
        #expect(progress.hasFullGame && progress.hasRemoveAds)
        #expect(progress.availability(of: "c4-01") == .lockedByProgress)
        #expect(progress.hintBalance == HintEconomy.startingHints + HintEconomy.fullGameBonus)
        // Aynı işlemin yeniden teslimi ve hak yenileme bonusu tekrar vermez.
        await shop.apply(transaction)
        await shop.refreshEntitlements()
        #expect(progress.hintBalance == HintEconomy.startingHints + HintEconomy.fullGameBonus)
    }

    @Test func removeAdsDoesNotUnlockChapters() async throws {
        _ = try await buy(.removeAds)
        #expect(shop.hasRemoveAds && !shop.hasFullGame)
        #expect(progress.hasRemoveAds && !progress.hasFullGame)
        #expect(progress.availability(of: "c4-01") == .requiresFullGame)
    }

    @Test func eachHintPackAddsTenHintsExactlyOnce() async throws {
        let first = try await buy(.hints10)
        _ = try await buy(.hints10)
        await shop.apply(first)
        #expect(progress.hintBalance == HintEconomy.startingHints + 2 * HintEconomy.packSize)
        #expect(progress.progress.grantedTransactionIDs.count == 2)
    }

    @Test func refundRevokesTheFullGame() async throws {
        _ = try await buy(.fullGame)
        #expect(shop.hasFullGame)
        let transaction = try #require(session.allTransactions().first { $0.productIdentifier == StoreService.ProductID.fullGame.rawValue })
        try session.refundTransaction(identifier: UInt(transaction.identifier))
        // İade, uygulamaya `Transaction.updates` ile iptal tarihi taşıyan işlem olarak gelir; servis bunu dinler.
        for _ in 0..<50 where shop.hasFullGame {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(!shop.hasFullGame)
        #expect(progress.availability(of: "c4-01") == .requiresFullGame)
    }
}
