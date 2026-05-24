import Foundation
import Observation
import StoreKit
import SwiftData

enum StoreServiceError: Error {
    case failedVerification
}

@MainActor
@Observable
final class StoreService {
    static let starterPackID = "com.nightfallprotocol.cosmetic.starter"
    static let premiumPassID = "com.nightfallprotocol.subscription.premium.monthly"
    static let nightmareSkinPackID = "com.nightfallprotocol.cosmetic.nightmare"

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    var isLoading = false
    var lastErrorKey: String?

    var productIDs: [String] {
        [Self.starterPackID, Self.premiumPassID, Self.nightmareSkinPackID]
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: productIDs)
            await refreshEntitlements()
        } catch {
            lastErrorKey = "error.store.unavailable"
        }
    }

    func catalogItems() -> [StoreCatalogItem] {
        [
            StoreCatalogItem(
                productID: Self.starterPackID,
                titleKey: "store.starter.title",
                descriptionKey: "store.starter.description",
                priceKey: "store.starter.price",
                category: .cosmetic,
                owned: purchasedProductIDs.contains(Self.starterPackID)
            ),
            StoreCatalogItem(
                productID: Self.premiumPassID,
                titleKey: "store.premiumPass.title",
                descriptionKey: "store.premiumPass.description",
                priceKey: "store.premiumPass.price",
                category: .pass,
                owned: purchasedProductIDs.contains(Self.premiumPassID)
            ),
            StoreCatalogItem(
                productID: Self.nightmareSkinPackID,
                titleKey: "store.nightmareSkin.title",
                descriptionKey: "store.nightmareSkin.description",
                priceKey: "store.nightmareSkin.price",
                category: .cosmetic,
                owned: purchasedProductIDs.contains(Self.nightmareSkinPackID)
            )
        ]
    }

    func purchase(_ item: StoreCatalogItem, context: ModelContext) async {
        if let product = products.first(where: { $0.id == item.productID }) {
            do {
                let result = try await product.purchase()

                switch result {
                case .success(let verification):
                    let transaction = try checkVerified(verification)
                    await transaction.finish()
                    markPurchased(productID: transaction.productID, context: context)
                case .userCancelled, .pending:
                    break
                @unknown default:
                    lastErrorKey = "error.purchase.failed"
                }
            } catch {
                lastErrorKey = "error.purchase.failed"
            }
        } else {
            markPurchased(productID: item.productID, context: context)
            lastErrorKey = "store.mock.purchase"
        }
    }

    func restorePurchases(context: ModelContext) async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            for productID in purchasedProductIDs {
                markPurchased(productID: productID, context: context)
            }
        } catch {
            lastErrorKey = "error.purchase.failed"
        }
    }

    private func refreshEntitlements() async {
        var purchased = Set<String>()

        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(entitlement) else { continue }
            purchased.insert(transaction.productID)
        }

        purchasedProductIDs = purchased
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreServiceError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func markPurchased(productID: String, context: ModelContext) {
        purchasedProductIDs.insert(productID)

        let state = PurchaseState(productId: productID, purchased: true, purchaseDate: Date())
        context.insert(state)
        try? context.save()
    }
}
