import SwiftUI
// RevenueCat temporarily disabled
// import RevenueCat
// import RevenueCatUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseService = PurchaseService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FVSpacing.xl) {
                    headerSection

                    featuresSection

                    // Show Pro status message since purchases are disabled
                    proAccessSection

                    legalSection
                }
                .padding()
            }
            .background(FVColors.groupedBackground)
            .navigationTitle("Pro Features")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
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

            Text("Pro Access Enabled")
                .font(FVTypography.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(FVColors.label)

            Text("You have full access to all features")
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

    private var proAccessSection: some View {
        VStack(spacing: FVSpacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)

            Text("Pro Access Active")
                .font(FVTypography.headline)
                .foregroundStyle(FVColors.label)

            Text("In-app purchases are currently disabled. You have full access to all Pro features during this testing period.")
                .font(FVTypography.subheadline)
                .foregroundStyle(FVColors.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(FVRadius.md)
    }

    private var legalSection: some View {
        VStack(spacing: FVSpacing.xs) {
            HStack(spacing: FVSpacing.md) {
                Link("Terms of Service", destination: URL(string: "https://procam360.app/terms")!)
                Text("•")
                Link("Privacy Policy", destination: URL(string: "https://procam360.app/privacy")!)
            }
            .font(FVTypography.caption)
            .foregroundStyle(FVColors.secondaryLabel)
        }
        .padding(.top, FVSpacing.md)
    }
}

struct UpgradePromptView: View {
    let feature: String
    @State private var showingPaywall = false
    @StateObject private var purchaseService = PurchaseService.shared

    var body: some View {
        VStack(spacing: FVSpacing.md) {
            // Since everyone has Pro access while RevenueCat is disabled,
            // this view shouldn't normally appear, but just in case:
            if purchaseService.isPro {
                // User has Pro access
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)

                Text("\(feature) is available")
                    .font(FVTypography.headline)
                    .foregroundStyle(FVColors.label)
            } else {
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
