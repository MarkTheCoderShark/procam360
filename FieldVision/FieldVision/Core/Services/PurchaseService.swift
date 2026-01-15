import Foundation
import StoreKit

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
    
    @Published private(set) var subscriptionStatus: SubscriptionTier = .free
    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private var updateListenerTask: Task<Void, Error>?
    
    private let productIdentifiers = [
        "com.fieldvision.pro.monthly",
        "com.fieldvision.pro.annual"
    ]
    
    private init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let products = try await Product.products(for: productIdentifiers)
            availableProducts = products.sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            return true
            
        case .userCancelled:
            return false
            
        case .pending:
            errorMessage = "Purchase is pending approval"
            return false
            
        @unknown default:
            errorMessage = "Unknown purchase result"
            return false
        }
    }
    
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
    }
    
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable {
                    hasActiveSubscription = true
                    
                    if transaction.productID.contains("annual") {
                        subscriptionStatus = .proAnnual
                    } else {
                        subscriptionStatus = .pro
                    }
                    break
                }
            }
        }
        
        if !hasActiveSubscription {
            subscriptionStatus = .free
        }
    }
    
    var isPro: Bool {
        subscriptionStatus == .pro || subscriptionStatus == .proAnnual
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum PurchaseError: LocalizedError {
    case failedVerification
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .productNotFound:
            return "Product not found"
        }
    }
}

extension Product {
    var formattedPrice: String {
        displayPrice
    }
    
    var periodText: String {
        guard let subscription = subscription else { return "" }
        
        switch subscription.subscriptionPeriod.unit {
        case .month:
            return subscription.subscriptionPeriod.value == 1 ? "/month" : "/\(subscription.subscriptionPeriod.value) months"
        case .year:
            return "/year"
        case .week:
            return "/week"
        case .day:
            return "/day"
        @unknown default:
            return ""
        }
    }
}
