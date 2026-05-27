import Foundation
import Combine

@MainActor
final class PremiumFlowManager: ObservableObject {
    @Published var requestedContext: PremiumPaywallContext?

    func request(_ context: PremiumPaywallContext) {
        requestedContext = context
    }

    func consume() -> PremiumPaywallContext? {
        let context = requestedContext
        requestedContext = nil
        return context
    }
}
