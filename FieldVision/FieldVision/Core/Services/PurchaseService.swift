import Foundation
// RevenueCat temporarily disabled - uncomment when ready for production
// import RevenueCat

enum SubscriptionTier: String, CaseIterable {
    case free = "free"
    case pro = "pro_monthly"
    case proAnnual = "pro_annual"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro Monthly"
        case .proAnnual: return "Pro Annual"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "3 projects",
                "100 photos per project",
                "Basic folders",
                "7-day photo history"
            ]
        case .pro, .proAnnual:
            return [
                "Unlimited projects",
                "Unlimited photos",
                "PDF report generation",
                "Team collaboration",
                "Priority support",
                "Offline sync",
                "Voice note transcription"
            ]
        }
    }
}

@MainActor
final class PurchaseService: ObservableObject {
    static let shared = PurchaseService()

    static let entitlementIdentifier = "Proflow Inspect Pro"

    @Published private(set) var isConfigured = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    // For now, everyone gets Pro access while RevenueCat is disabled
    var isPro: Bool {
        true // Grant Pro access while purchases are disabled
    }

    var subscriptionStatus: SubscriptionTier {
        .pro // Grant Pro access while purchases are disabled
    }

    private init() {}

    func configure() {
        // RevenueCat disabled for TestFlight testing
        print("PurchaseService: RevenueCat disabled - granting Pro access")
        isConfigured = false
    }

    func loadOfferings() async {
        // No-op while RevenueCat is disabled
    }

    func refreshCustomerInfo() async {
        // No-op while RevenueCat is disabled
    }

    func purchase(_ packageId: String) async throws -> Bool {
        errorMessage = "Purchases not available in this build"
        return false
    }

    func restorePurchases() async throws {
        errorMessage = "Purchases not available in this build"
    }

    func login(userId: String) async throws {
        // No-op while RevenueCat is disabled
    }

    func logout() async throws {
        // No-op while RevenueCat is disabled
    }
}

enum PurchaseError: LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseFailed(String)

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed(let message):
            return message
        }
    }
}
