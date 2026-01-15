import SwiftUI

struct FVLoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: FVSpacing.md) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(FVColors.primary)

            Text(message)
                .font(FVTypography.body)
                .foregroundStyle(FVColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FVColors.background)
    }
}

struct FVLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: FVSpacing.md) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
            .padding(FVSpacing.xl)
            .background(.ultraThinMaterial)
            .cornerRadius(FVRadius.lg)
        }
    }
}

struct FVEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String = "Try Again"

    var body: some View {
        VStack(spacing: FVSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(FVColors.tertiaryLabel)

            VStack(spacing: FVSpacing.xs) {
                Text(title)
                    .font(FVTypography.headline)
                    .foregroundStyle(FVColors.label)

                Text(message)
                    .font(FVTypography.body)
                    .foregroundStyle(FVColors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }

            if let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(FVTypography.subheadline)
                        .fontWeight(.semibold)
                }
                .buttonStyle(FVPrimaryButtonStyle())
            }
        }
        .padding(FVSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FVErrorView: View {
    let error: Error
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: FVSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(FVColors.error)

            VStack(spacing: FVSpacing.xs) {
                Text("Something went wrong")
                    .font(FVTypography.headline)
                    .foregroundStyle(FVColors.label)

                Text(error.localizedDescription)
                    .font(FVTypography.body)
                    .foregroundStyle(FVColors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }

            if let retry = retry {
                Button(action: retry) {
                    HStack(spacing: FVSpacing.xs) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                }
                .buttonStyle(FVPrimaryButtonStyle())
            }
        }
        .padding(FVSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Loading") {
    FVLoadingView(message: "Loading projects...")
}

#Preview("Empty State") {
    FVEmptyStateView(
        icon: "folder.badge.plus",
        title: "No Projects Yet",
        message: "Create your first project to start documenting job sites.",
        action: {}
    )
}

#Preview("Error") {
    FVErrorView(
        error: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network connection failed"]),
        retry: {}
    )
}
