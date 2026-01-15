import SwiftUI

struct FVPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FVTypography.headline)
            .padding(.horizontal, FVSpacing.lg)
            .padding(.vertical, FVSpacing.sm)
            .background(configuration.isPressed ? FVColors.Fallback.primary.opacity(0.8) : FVColors.Fallback.primary)
            .foregroundStyle(.white)
            .cornerRadius(FVRadius.md)
    }
}

struct FVPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FVSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }

                Text(title)
                    .font(FVTypography.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FVSpacing.sm)
            .background(isDisabled ? FVColors.tertiaryLabel : FVColors.Fallback.primary)
            .foregroundStyle(.white)
            .cornerRadius(FVRadius.md)
        }
        .disabled(isLoading || isDisabled)
    }
}

struct FVSecondaryButton: View {
    let title: String
    var icon: String?
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FVSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: FVColors.Fallback.primary))
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                }

                Text(title)
                    .font(FVTypography.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FVSpacing.sm)
            .background(FVColors.secondaryBackground)
            .foregroundStyle(FVColors.Fallback.primary)
            .cornerRadius(FVRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: FVRadius.md)
                    .stroke(FVColors.Fallback.primary, lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }
}

struct FVIconButton: View {
    let icon: String
    var size: CGFloat = 44
    var backgroundColor: Color = FVColors.secondaryBackground
    var foregroundColor: Color = FVColors.label
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(foregroundColor)
                .frame(width: size, height: size)
                .background(backgroundColor)
                .clipShape(Circle())
        }
    }
}

struct FVFloatingActionButton: View {
    let icon: String
    var size: CGFloat = 60
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(FVColors.Fallback.primary)
                .clipShape(Circle())
                .shadow(color: FVColors.Fallback.primary.opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        FVPrimaryButton(title: "Sign In", action: {})
        FVPrimaryButton(title: "Loading...", isLoading: true, action: {})
        FVSecondaryButton(title: "Create Project", icon: "plus", action: {})
        HStack {
            FVIconButton(icon: "camera.fill", action: {})
            FVIconButton(icon: "photo", action: {})
            FVFloatingActionButton(icon: "camera.fill", action: {})
        }
    }
    .padding()
}
