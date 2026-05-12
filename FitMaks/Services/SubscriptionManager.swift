import Foundation
import StoreKit

@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    private static let monthlyID = "fitmaks_pro_monthly"
    private static let yearlyID = "fitmaks_pro_yearly"
    private static let productIDs: Set<String> = [monthlyID, yearlyID]

    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var isLoading = false
    private(set) var purchaseError: String?
    private(set) var activeProductID: String?

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyID } }
    var yearlyProduct: Product? { products.first { $0.id == Self.yearlyID } }

    private var updateTask: Task<Void, Never>?

    private init() {
        updateTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await tx.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }

    deinit {
        updateTask?.cancel()
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            purchaseError = "Could not load products."
        }
    }

    func purchase(_ product: Product) async {
        purchaseError = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    await refreshEntitlements()
                }
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed. Please try again."
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var foundPro = false
        var foundProductID: String?
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               Self.productIDs.contains(tx.productID) {
                foundPro = true
                foundProductID = tx.productID
            }
        }
        isPro = foundPro
        activeProductID = foundProductID
    }
}
