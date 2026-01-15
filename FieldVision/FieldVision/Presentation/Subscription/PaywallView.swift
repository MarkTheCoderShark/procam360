import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseService = PurchaseService.shared
    
    @State private var selectedProduct: Product?
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
                if let firstProduct = purchaseService.availableProducts.first {
                    selectedProduct = firstProduct
                }
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
            if purchaseService.isLoading && purchaseService.availableProducts.isEmpty {
                ProgressView()
                    .padding()
            } else {
                ForEach(purchaseService.availableProducts, id: \.id) { product in
                    ProductCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        onSelect: { selectedProduct = product }
                    )
                }
                
                purchaseButton
                
                restoreButton
            }
        }
    }
    
    private var purchaseButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            Task {
                isPurchasing = true
                do {
                    let success = try await purchaseService.purchase(product)
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
        .disabled(selectedProduct == nil || isPurchasing)
    }
    
    private var restoreButton: some View {
        Button {
            Task {
                await purchaseService.restorePurchases()
                if purchaseService.isPro {
                    dismiss()
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
                Link("Terms of Service", destination: URL(string: "https://fieldvision.app/terms")!)
                Text("•")
                Link("Privacy Policy", destination: URL(string: "https://fieldvision.app/privacy")!)
            }
            .font(FVTypography.caption)
            .foregroundStyle(FVColors.secondaryLabel)
        }
        .padding(.top, FVSpacing.md)
    }
}

struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var isAnnual: Bool {
        product.id.contains("annual")
    }
    
    private var savings: String? {
        guard isAnnual else { return nil }
        return "Save 17%"
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
                    Text(product.formattedPrice)
                        .font(FVTypography.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(FVColors.label)
                    
                    Text(product.periodText)
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

#Preview {
    PaywallView()
}
