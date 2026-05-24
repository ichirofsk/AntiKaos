import Foundation
import StoreKit
import Combine

@MainActor
final class PremiumAccessManager: ObservableObject {
    static let unlimitedHistoryProductID = "br.com.antonio.Antikaos.unlimitedHistory"
    static let unlimitedDeadlinesProductID = "br.com.antonio.Antikaos.unlimitedDeadlines"

    @Published private(set) var hasUnlimitedHistory = false
    @Published private(set) var hasUnlimitedDeadlines = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = observeTransactions()

        Task {
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func refreshEntitlements() async {
        var historyUnlocked = false
        var deadlinesUnlocked = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }

            if transaction.productID == Self.unlimitedHistoryProductID {
                historyUnlocked = true
            }

            if transaction.productID == Self.unlimitedDeadlinesProductID {
                deadlinesUnlocked = true
            }
        }

        hasUnlimitedHistory = historyUnlocked
        hasUnlimitedDeadlines = deadlinesUnlocked
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            return
        }

        await refreshEntitlements()
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
}
