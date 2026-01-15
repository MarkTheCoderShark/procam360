import SwiftUI

struct FVTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String?
    
    var body: some View {
        HStack(spacing: FVSpacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(FVColors.tertiaryLabel)
                    .frame(width: 20)
            }
            
            TextField(placeholder, text: $text)
                .font(FVTypography.body)
        }
        .padding(.horizontal, FVSpacing.md)
        .padding(.vertical, FVSpacing.sm)
        .background(FVColors.secondaryBackground)
        .cornerRadius(FVRadius.md)
    }
}

struct FVSecureField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String?
    @State private var isSecure = true
    
    var body: some View {
        HStack(spacing: FVSpacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(FVColors.tertiaryLabel)
                    .frame(width: 20)
            }
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(FVTypography.body)
            
            Button {
                isSecure.toggle()
            } label: {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundStyle(FVColors.tertiaryLabel)
            }
        }
        .padding(.horizontal, FVSpacing.md)
        .padding(.vertical, FVSpacing.sm)
        .background(FVColors.secondaryBackground)
        .cornerRadius(FVRadius.md)
    }
}

#Preview {
    VStack(spacing: 16) {
        FVTextField(placeholder: "Email", text: .constant(""), icon: "envelope")
        FVSecureField(placeholder: "Password", text: .constant(""), icon: "lock")
    }
    .padding()
}
