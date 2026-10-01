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
    static let premiumPassID = "com.nightfallprotocol.subscription.premium.monthly"

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    var isLoading = false
    var lastErrorKey: String?
    @ObservationIgnored private var transactionListener: Task<Void, Never>?

    var hasPremiumAccess: Bool {
        purchasedProductIDs.contains(Self.premiumPassID)
    }

    func startMonitoring(context: ModelContext) {
        guard transactionListener == nil else { return }
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled, let self,
                      let transaction = try? self.checkVerified(result),
                      self.productIDs.contains(transaction.productID) else { continue }
                await self.refreshEntitlements()
                self.synchronizePurchaseStates(context: context)
                await transaction.finish()
            }
        }
    }

    func refreshAccess(context: ModelContext) async {
        await refreshEntitlements()
        synchronizePurchaseStates(context: context)
    }

    var productIDs: [String] {
        [Self.premiumPassID]
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
                productID: Self.premiumPassID,
                titleKey: "store.premiumPass.title",
                descriptionKey: "store.premiumPass.description",
                priceKey: "store.premiumPass.price",
                displayPrice: displayPrice(for: Self.premiumPassID),
                category: .pass,
                owned: purchasedProductIDs.contains(Self.premiumPassID)
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
            #if os(visionOS)
            guard let purchaseAction else {
                lastErrorKey = "error.purchase.failed"
                return
            }
            result = try await purchaseAction(product)
            #else
            if let purchaseAction {
                result = try await purchaseAction(product)
            } else {
                result = try await product.purchase()
            }
            #endif

            await completePurchase(result, context: context)
        } catch {
            lastErrorKey = "error.purchase.failed"
        }
    }

    func restorePurchases(context: ModelContext) async {
        lastErrorKey = nil

        do {
            try await AppStore.sync()
            await refreshAccess(context: context)
        } catch {
            lastErrorKey = "error.purchase.failed"
        }
    }

    private func completePurchase(_ result: Product.PurchaseResult, context: ModelContext) async {
        switch result {
        case .success(let verification):
            do {
                let transaction = try checkVerified(verification)
                guard productIDs.contains(transaction.productID) else {
                    throw StoreServiceError.failedVerification
                }
                if isActive(transaction) {
                    purchasedProductIDs.insert(transaction.productID)
                } else {
                    purchasedProductIDs.remove(transaction.productID)
                }
                synchronizePurchaseStates(context: context)
                await transaction.finish()
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
            guard let transaction = try? checkVerified(entitlement),
                  productIDs.contains(transaction.productID),
                  isActive(transaction) else { continue }
            purchased.insert(transaction.productID)
        }

        purchasedProductIDs = purchased
    }

    private func isActive(_ transaction: Transaction) -> Bool {
        transaction.revocationDate == nil && !transaction.isUpgraded &&
            (transaction.expirationDate.map({ $0 > Date() }) ?? true)
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreServiceError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func synchronizePurchaseStates(context: ModelContext) {
        do {
            let savedStates = try context.fetch(FetchDescriptor<PurchaseState>())
            for productID in productIDs {
                let active = purchasedProductIDs.contains(productID)
                let matches = savedStates.filter { $0.productId == productID }
                if let state = matches.first {
                    let wasPurchased = state.purchased
                    state.purchased = active
                    if active && !wasPurchased { state.purchaseDate = Date() }
                    for duplicate in matches.dropFirst() { context.delete(duplicate) }
                } else if active {
                    context.insert(PurchaseState(productId: productID, purchased: true, purchaseDate: Date()))
                }
            }
            try context.save()
        } catch {
            lastErrorKey = "state.error"
        }
    }
}
