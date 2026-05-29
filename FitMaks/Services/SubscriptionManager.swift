import Foundation
import StoreKit

@MainActor @Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    private static let monthlyID = "fitmaks_pro_monthly"
    private static let yearlyID = "fitmaks_pro_yearly"
    private static let productIDs: Set<String> = [monthlyID, yearlyID]

    private static let testerOverrideKey = "sf_tester_pro_override"
    private static let testerCode = "SHAPEFORGE2026"

    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var isLoading = false
    private(set) var purchaseError: String?
    private(set) var activeProductID: String?

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyID } }
    var yearlyProduct: Product? { products.first { $0.id == Self.yearlyID } }

    private nonisolated(unsafe) var updateTask: Task<Void, Never>?

    private init() {
        if UserDefaults.standard.bool(forKey: Self.testerOverrideKey) {
            isPro = true
        }
        updateTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await tx.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
        Task { await refreshEntitlements() }
    }

    deinit {
        updateTask?.cancel()
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        purchaseError = nil

        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            do {
                let storeProducts = try await Product.products(for: Self.productIDs)
                products = storeProducts.sorted { $0.price < $1.price }
                if !products.isEmpty { return }
            } catch {
                if attempt == maxAttempts {
                    purchaseError = error.localizedDescription.isEmpty
                        ? "Could not load products."
                        : error.localizedDescription
                    return
                }
            }
            try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 500_000_000)
        }

        if products.isEmpty {
            purchaseError = "No subscription products were returned."
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
        purchaseError = nil
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = "Restore failed. Check your connection and try again."
        }
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
        isPro = foundPro || UserDefaults.standard.bool(forKey: Self.testerOverrideKey)
        activeProductID = foundProductID
    }

    func redeemTesterCode(_ code: String) -> Bool {
        guard code.uppercased() == Self.testerCode else { return false }
        UserDefaults.standard.set(true, forKey: Self.testerOverrideKey)
        isPro = true
        return true
    }
}
