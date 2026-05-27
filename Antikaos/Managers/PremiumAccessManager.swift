import Foundation
import StoreKit
import Combine
import WidgetKit

@MainActor
final class PremiumAccessManager: ObservableObject {
    static let premiumProductID = "br.com.antonio.Antikaos.premium"

    @Published private(set) var hasPremium = false
    @Published private(set) var premiumProduct: Product?
    @Published private(set) var isLoadingProduct = false
    @Published private(set) var purchaseErrorMessage: String?

    var hasUnlimitedHistory: Bool { hasPremium }
    var hasUnlimitedDeadlines: Bool { hasPremium }
    var hasWidgetAccess: Bool { hasPremium }

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = observeTransactions()

        Task {
            await loadProduct()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProduct() async {
        guard premiumProduct == nil else { return }

        isLoadingProduct = true
        defer { isLoadingProduct = false }

        do {
            premiumProduct = try await Product.products(for: [Self.premiumProductID]).first
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var premiumUnlocked = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }

            if transaction.productID == Self.premiumProductID {
                premiumUnlocked = true
            }
        }

        hasPremium = premiumUnlocked
        syncWidgetPremiumAccess()
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            return
        }

        await refreshEntitlements()
    }

    func purchasePremium() async -> Bool {
        await loadProduct()

        guard let premiumProduct else {
            purchaseErrorMessage = "Não foi possível carregar o produto premium."
            return false
        }

        do {
            let result = try await premiumProduct.purchase()

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseErrorMessage = "Não foi possível verificar a compra."
                    return false
                }

                await transaction.finish()
                await refreshEntitlements()
                return hasPremium
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseErrorMessage = error.localizedDescription
            return false
        }
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    private func syncWidgetPremiumAccess() {
        let defaults = UserDefaults(suiteName: WidgetShared.appGroupID)
        defaults?.set(hasPremium, forKey: WidgetShared.hasPremiumAccessKey)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.widgetKind)
    }
}
