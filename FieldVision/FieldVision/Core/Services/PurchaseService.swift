import Foundation
import RevenueCat

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
final class PurchaseService: NSObject, ObservableObject {
    static let shared = PurchaseService()
    
    static let entitlementIdentifier = "Proflow Inspect Pro"
    static let apiKey = "test_OVNNLuZhIReVVESEfewaBCijaBL"
    
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var offerings: Offerings?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    var isPro: Bool {
        customerInfo?.entitlements[Self.entitlementIdentifier]?.isActive == true
    }
    
    var subscriptionStatus: SubscriptionTier {
        guard let entitlement = customerInfo?.entitlements[Self.entitlementIdentifier],
              entitlement.isActive else {
            return .free
        }
        
        if entitlement.productIdentifier.contains("annual") || entitlement.productIdentifier.contains("yearly") {
            return .proAnnual
        }
        return .pro
    }
    
    var currentOffering: Offering? {
        offerings?.current
    }
    
    var availablePackages: [Package] {
        currentOffering?.availablePackages ?? []
    }
    
    var monthlyPackage: Package? {
        currentOffering?.monthly
    }
    
    var annualPackage: Package? {
        currentOffering?.annual
    }
    
    private override init() {
        super.init()
    }
    
    func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        
        let configuration = Configuration.Builder(withAPIKey: Self.apiKey)
            .with(storeKitVersion: .storeKit2)
            .build()
        
        Purchases.configure(with: configuration)
        Purchases.shared.delegate = self
        
        Task {
            await loadOfferings()
            await refreshCustomerInfo()
        }
        
        listenForCustomerInfoUpdates()
    }
    
    func loadOfferings() async {
        isLoading = true
        errorMessage = nil
        
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            errorMessage = "Failed to load offerings: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func refreshCustomerInfo() async {
        do {
            customerInfo = try await Purchases.shared.customerInfo()
        } catch {
            errorMessage = "Failed to get customer info: \(error.localizedDescription)"
        }
    }
    
    func purchase(_ package: Package) async throws -> Bool {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            if result.userCancelled {
                return false
            }
            
            customerInfo = result.customerInfo
            return isPro
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    func restorePurchases() async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            customerInfo = try await Purchases.shared.restorePurchases()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    func login(userId: String) async throws {
        let (customerInfo, _) = try await Purchases.shared.logIn(userId)
        self.customerInfo = customerInfo
    }
    
    func logout() async throws {
        customerInfo = try await Purchases.shared.logOut()
    }
    
    private func listenForCustomerInfoUpdates() {
        Task {
            for await info in Purchases.shared.customerInfoStream {
                await MainActor.run {
                    self.customerInfo = info
                }
            }
        }
    }
}

extension PurchaseService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
        }
    }
    
    nonisolated func purchases(_ purchases: Purchases, readyForPromotedProduct product: StoreProduct, purchase startPurchase: @escaping StartPurchaseBlock) {
        startPurchase { transaction, customerInfo, error, cancelled in
            Task { @MainActor in
                if let customerInfo = customerInfo {
                    self.customerInfo = customerInfo
                }
            }
        }
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
