import SwiftUI
import RevenueCat
import RevenueCatUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseService = PurchaseService.shared
    
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FVSpacing.xl) {
                    headerSection
                    
                    featuresSection
                    
                    productsSection
                    
                    legalSection
                }
                .padding()
            }
            .background(FVColors.groupedBackground)
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                selectedPackage = purchaseService.annualPackage ?? purchaseService.monthlyPackage
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: FVSpacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 56))
                .foregroundStyle(.linearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Text("Unlock Full Power")
                .font(FVTypography.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(FVColors.label)
            
            Text("Get unlimited access to all features")
                .font(FVTypography.body)
                .foregroundStyle(FVColors.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .padding(.top, FVSpacing.lg)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: FVSpacing.sm) {
            ForEach(SubscriptionTier.pro.features, id: \.self) { feature in
                HStack(spacing: FVSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    
                    Text(feature)
                        .font(FVTypography.body)
                        .foregroundStyle(FVColors.label)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FVColors.background)
        .cornerRadius(FVRadius.md)
    }
    
    private var productsSection: some View {
        VStack(spacing: FVSpacing.md) {
            if purchaseService.isLoading && purchaseService.availablePackages.isEmpty {
                ProgressView()
                    .padding()
            } else {
                ForEach(purchaseService.availablePackages, id: \.identifier) { package in
                    PackageCard(
                        package: package,
                        isSelected: selectedPackage?.identifier == package.identifier,
                        onSelect: { selectedPackage = package }
                    )
                }
                
                purchaseButton
                
                restoreButton
            }
        }
    }
    
    private var purchaseButton: some View {
        Button {
            guard let package = selectedPackage else { return }
            Task {
                isPurchasing = true
                do {
                    let success = try await purchaseService.purchase(package)
                    if success {
                        dismiss()
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
                isPurchasing = false
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Subscribe Now")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(FVColors.Fallback.primary)
            .foregroundStyle(.white)
            .cornerRadius(FVRadius.md)
        }
        .disabled(selectedPackage == nil || isPurchasing)
    }
    
    private var restoreButton: some View {
        Button {
            Task {
                do {
                    try await purchaseService.restorePurchases()
                    if purchaseService.isPro {
                        dismiss()
                    }
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(FVTypography.subheadline)
                .foregroundStyle(FVColors.Fallback.primary)
        }
    }
    
    private var legalSection: some View {
        VStack(spacing: FVSpacing.xs) {
            Text("Subscription auto-renews unless canceled at least 24 hours before the end of the current period. Manage subscriptions in Settings.")
                .font(FVTypography.caption)
                .foregroundStyle(FVColors.tertiaryLabel)
                .multilineTextAlignment(.center)
            
            HStack(spacing: FVSpacing.md) {
                Link("Terms of Service", destination: URL(string: "https://proflowinspect.app/terms")!)
                Text("•")
                Link("Privacy Policy", destination: URL(string: "https://proflowinspect.app/privacy")!)
            }
            .font(FVTypography.caption)
            .foregroundStyle(FVColors.secondaryLabel)
        }
        .padding(.top, FVSpacing.md)
    }
}

struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var isAnnual: Bool {
        package.packageType == .annual
    }
    
    private var savings: String? {
        guard isAnnual else { return nil }
        return "Save 17%"
    }
    
    private var periodText: String {
        switch package.packageType {
        case .monthly: return "/month"
        case .annual: return "/year"
        case .weekly: return "/week"
        case .lifetime: return "one-time"
        default: return ""
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: FVSpacing.xxxs) {
                    HStack {
                        Text(isAnnual ? "Annual" : "Monthly")
                            .font(FVTypography.headline)
                            .foregroundStyle(FVColors.label)
                        
                        if let savings = savings {
                            Text(savings)
                                .font(FVTypography.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, FVSpacing.xs)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .cornerRadius(FVRadius.xs)
                        }
                    }
                    
                    Text(isAnnual ? "Best value" : "Flexible")
                        .font(FVTypography.caption)
                        .foregroundStyle(FVColors.secondaryLabel)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: FVSpacing.xxxs) {
                    Text(package.storeProduct.localizedPriceString)
                        .font(FVTypography.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(FVColors.label)
                    
                    Text(periodText)
                        .font(FVTypography.caption)
                        .foregroundStyle(FVColors.secondaryLabel)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? FVColors.Fallback.primary : FVColors.tertiaryLabel)
                    .padding(.leading, FVSpacing.sm)
            }
            .padding()
            .background(FVColors.background)
            .cornerRadius(FVRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: FVRadius.md)
                    .stroke(isSelected ? FVColors.Fallback.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct UpgradePromptView: View {
    let feature: String
    @State private var showingPaywall = false
    
    var body: some View {
        VStack(spacing: FVSpacing.md) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(FVColors.tertiaryLabel)
            
            Text("\(feature) is a Pro feature")
                .font(FVTypography.headline)
                .foregroundStyle(FVColors.label)
            
            Text("Upgrade to Pro to unlock this feature and more")
                .font(FVTypography.subheadline)
                .foregroundStyle(FVColors.secondaryLabel)
                .multilineTextAlignment(.center)
            
            Button {
                showingPaywall = true
            } label: {
                Text("Upgrade to Pro")
                    .fontWeight(.semibold)
                    .padding(.horizontal, FVSpacing.xl)
                    .padding(.vertical, FVSpacing.sm)
                    .background(FVColors.Fallback.primary)
                    .foregroundStyle(.white)
                    .cornerRadius(FVRadius.md)
            }
        }
        .padding()
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
}

struct RevenueCatPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        PaywallView()
            .onPurchaseCompleted { customerInfo in
                dismiss()
            }
            .onRestoreCompleted { customerInfo in
                if customerInfo.entitlements[PurchaseService.entitlementIdentifier]?.isActive == true {
                    dismiss()
                }
            }
    }
}

#Preview {
    PaywallView()
}
