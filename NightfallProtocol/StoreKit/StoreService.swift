import Foundation
import Observation
import StoreKit
import SwiftData

enum StoreServiceError: Error {
    case failedVerification
}

typealias ProductPurchaseHandler = @MainActor (Product) async throws -> Product.PurchaseResult

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
            lastErrorKey = products.isEmpty ? "error.store.unavailable" : nil
        } catch {
            products = []
            lastErrorKey = "error.store.unavailable"
        }
    }

    func catalogItems() -> [StoreCatalogItem] {
        guard !products.isEmpty else { return [] }

        let availableProductIDs = Set(products.map(\.id))
        return [
            StoreCatalogItem(
                productID: Self.starterPackID,
                titleKey: "store.starter.title",
                descriptionKey: "store.starter.description",
                priceKey: "store.starter.price",
                displayPrice: displayPrice(for: Self.starterPackID),
                category: .cosmetic,
                owned: purchasedProductIDs.contains(Self.starterPackID)
            ),
            StoreCatalogItem(
                productID: Self.premiumPassID,
                titleKey: "store.premiumPass.title",
                descriptionKey: "store.premiumPass.description",
                priceKey: "store.premiumPass.price",
                displayPrice: displayPrice(for: Self.premiumPassID),
                category: .pass,
                owned: purchasedProductIDs.contains(Self.premiumPassID)
            ),
            StoreCatalogItem(
                productID: Self.nightmareSkinPackID,
                titleKey: "store.nightmareSkin.title",
                descriptionKey: "store.nightmareSkin.description",
                priceKey: "store.nightmareSkin.price",
                displayPrice: displayPrice(for: Self.nightmareSkinPackID),
                category: .cosmetic,
                owned: purchasedProductIDs.contains(Self.nightmareSkinPackID)
            )
        ]
        .filter { availableProductIDs.contains($0.productID) }
    }

    func purchase(_ item: StoreCatalogItem, context: ModelContext, purchaseAction: ProductPurchaseHandler? = nil) async {
        lastErrorKey = nil

        guard let product = products.first(where: { $0.id == item.productID }) else {
            lastErrorKey = "error.store.unavailable"
            return
        }

        do {
            let result: Product.PurchaseResult
            if let purchaseAction {
                result = try await purchaseAction(product)
            } else {
                #if os(visionOS)
                lastErrorKey = "error.purchase.failed"
                return
                #else
                result = try await product.purchase()
                #endif
            }

            await completePurchase(result, context: context)
        } catch {
            lastErrorKey = "error.purchase.failed"
        }
    }

    func restorePurchases(context: ModelContext) async {
        lastErrorKey = nil

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

    private func completePurchase(_ result: Product.PurchaseResult, context: ModelContext) async {
        switch result {
        case .success(let verification):
            do {
                let transaction = try checkVerified(verification)
                await transaction.finish()
                markPurchased(productID: transaction.productID, context: context)
                lastErrorKey = nil
            } catch {
                lastErrorKey = "error.purchase.failed"
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            lastErrorKey = "error.purchase.failed"
        }
    }

    private func displayPrice(for productID: String) -> String? {
        products.first(where: { $0.id == productID })?.displayPrice
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
