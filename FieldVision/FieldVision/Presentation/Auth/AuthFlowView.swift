import SwiftUI
import AuthenticationServices

struct AuthFlowView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isShowingRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                logoSection

                Spacer()

                if isShowingRegister {
                    RegisterFormView(isShowingRegister: $isShowingRegister)
                } else {
                    LoginFormView(isShowingRegister: $isShowingRegister)
                }

                Spacer()
            }
            .padding(.horizontal, FVSpacing.lg)
            .background(FVColors.background)
        }
    }

    private var logoSection: some View {
        VStack(spacing: FVSpacing.md) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(FVColors.Fallback.primary)

            Text("Pro Cam 360")
                .font(FVTypography.largeTitle)
                .foregroundStyle(FVColors.label)

            Text("Job site documentation made simple")
                .font(FVTypography.subheadline)
                .foregroundStyle(FVColors.secondaryLabel)

            #if DEBUG
            Button {
                authViewModel.loginWithTestAccount()
            } label: {
                Text("Continue as Test User")
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.Fallback.primary)
                    .padding(.horizontal, FVSpacing.md)
                    .padding(.vertical, FVSpacing.xs)
                    .background(FVColors.Fallback.primary.opacity(0.1))
                    .cornerRadius(FVRadius.sm)
            }
            .padding(.top, FVSpacing.sm)
            #endif
        }
    }
}

struct LoginFormView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isShowingRegister: Bool
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        VStack(spacing: FVSpacing.md) {
            VStack(spacing: FVSpacing.sm) {
                FVTextField(
                    placeholder: "Email",
                    text: $authViewModel.email,
                    icon: "envelope"
                )
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }

                FVSecureField(
                    placeholder: "Password",
                    text: $authViewModel.password,
                    icon: "lock"
                )
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { Task { await authViewModel.login() } }
            }

            if let error = authViewModel.error {
                Text(error.localizedDescription)
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.error)
                    .multilineTextAlignment(.center)
            }

            FVPrimaryButton(
                title: "Sign In",
                isLoading: authViewModel.isLoading
            ) {
                Task { await authViewModel.login() }
            }

            dividerSection

            appleSignInButton

            Button {
                withAnimation { isShowingRegister = true }
            } label: {
                Text("Don't have an account? ")
                    .foregroundStyle(FVColors.secondaryLabel) +
                Text("Sign Up")
                    .foregroundStyle(FVColors.Fallback.primary)
                    .fontWeight(.semibold)
            }
            .font(FVTypography.subheadline)
            .padding(.top, FVSpacing.sm)
        }
    }

    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(FVColors.separator)
                .frame(height: 1)

            Text("or")
                .font(FVTypography.caption)
                .foregroundStyle(FVColors.tertiaryLabel)
                .padding(.horizontal, FVSpacing.xs)

            Rectangle()
                .fill(FVColors.separator)
                .frame(height: 1)
        }
        .padding(.vertical, FVSpacing.xs)
    }

    private var appleSignInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            Task {
                await authViewModel.handleAppleSignIn(result)
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .cornerRadius(FVRadius.md)
    }
}

struct RegisterFormView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isShowingRegister: Bool
    @FocusState private var focusedField: Field?

    enum Field {
        case name, email, password, confirmPassword
    }

    var body: some View {
        VStack(spacing: FVSpacing.md) {
            VStack(spacing: FVSpacing.sm) {
                FVTextField(
                    placeholder: "Full Name",
                    text: $authViewModel.name,
                    icon: "person"
                )
                .textContentType(.name)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .email }

                FVTextField(
                    placeholder: "Email",
                    text: $authViewModel.email,
                    icon: "envelope"
                )
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }

                FVSecureField(
                    placeholder: "Password",
                    text: $authViewModel.password,
                    icon: "lock"
                )
                .textContentType(.newPassword)
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit { focusedField = .confirmPassword }

                FVSecureField(
                    placeholder: "Confirm Password",
                    text: $authViewModel.confirmPassword,
                    icon: "lock.fill"
                )
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirmPassword)
                .submitLabel(.go)
                .onSubmit { Task { await authViewModel.register() } }
            }

            if let error = authViewModel.error {
                Text(error.localizedDescription)
                    .font(FVTypography.caption)
                    .foregroundStyle(FVColors.error)
                    .multilineTextAlignment(.center)
            }

            FVPrimaryButton(
                title: "Create Account",
                isLoading: authViewModel.isLoading
            ) {
                Task { await authViewModel.register() }
            }

            Button {
                withAnimation { isShowingRegister = false }
            } label: {
                Text("Already have an account? ")
                    .foregroundStyle(FVColors.secondaryLabel) +
                Text("Sign In")
                    .foregroundStyle(FVColors.Fallback.primary)
                    .fontWeight(.semibold)
            }
            .font(FVTypography.subheadline)
            .padding(.top, FVSpacing.sm)
        }
    }
}

#Preview {
    AuthFlowView()
        .environmentObject(AuthViewModel())
}
