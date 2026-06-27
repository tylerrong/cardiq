import SwiftUI
import AuthenticationServices

/// Shown when Supabase is configured and there is no active session. Supports
/// email/password sign in & sign up plus native Sign in with Apple, handing the
/// resulting user back to `AppState`.
struct LoginView: View {
    @Environment(AppState.self) private var appState

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !isWorking
    }

    var body: some View {
        ZStack {
            CIQColors.Fallback.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: CIQSpacing.xl) {
                    header
                    emailForm
                    orDivider
                    appleButton
                    CIQDisclaimerView("Your card images and collection stay private to your account.")
                }
                .padding(.horizontal, CIQSpacing.xl)
                .padding(.top, CIQSpacing.xxxl)
                .padding(.bottom, CIQSpacing.xxl)
            }
        }
    }

    private var header: some View {
        VStack(spacing: CIQSpacing.md) {
            Image(systemName: "rectangle.stack.badge.person.crop")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(CIQColors.Fallback.accentPrimary)

            VStack(spacing: CIQSpacing.xs) {
                Text(isSignUp ? "Create your account" : "Welcome back")
                    .font(CIQFont.displayMedium)
                    .foregroundStyle(CIQColors.Fallback.textPrimary)
                Text("Sync your vault, scans, and grades across devices.")
                    .font(CIQFont.subheadline)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var emailForm: some View {
        VStack(spacing: CIQSpacing.sm) {
            field(
                icon: "envelope",
                placeholder: "Email",
                text: $email,
                isSecure: false,
                field: .email
            )
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.emailAddress)
            .submitLabel(.next)
            .onSubmit { focusedField = .password }

            field(
                icon: "lock",
                placeholder: "Password",
                text: $password,
                isSecure: true,
                field: .password
            )
            .textContentType(isSignUp ? .newPassword : .password)
            .submitLabel(.go)
            .onSubmit { if canSubmit { submit() } }

            if let errorMessage {
                message(errorMessage, color: CIQColors.Fallback.negative)
            }
            if let infoMessage {
                message(infoMessage, color: CIQColors.Fallback.accentPrimary)
            }

            Button(action: submit) {
                HStack(spacing: CIQSpacing.xs) {
                    if isWorking { ProgressView().tint(.black) }
                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canSubmit ? CIQColors.Fallback.accentPrimary : CIQColors.Fallback.accentPrimary.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: CIQRadius.md))
            }
            .disabled(!canSubmit)
            .padding(.top, CIQSpacing.xxs)

            Button {
                withAnimation { isSignUp.toggle() }
                errorMessage = nil
                infoMessage = nil
            } label: {
                Text(isSignUp ? "Have an account? Sign in" : "New here? Create an account")
                    .font(CIQFont.footnote)
                    .foregroundStyle(CIQColors.Fallback.textSecondary)
            }
            .padding(.top, CIQSpacing.xxs)
        }
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, isSecure: Bool, field: Field) -> some View {
        HStack(spacing: CIQSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(CIQColors.Fallback.textTertiary)
                .frame(width: 20)
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .foregroundStyle(CIQColors.Fallback.textPrimary)
            .focused($focusedField, equals: field)
        }
        .padding(.horizontal, CIQSpacing.md)
        .frame(height: 50)
        .background(CIQColors.Fallback.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: CIQRadius.md))
    }

    private func message(_ text: String, color: Color) -> some View {
        Text(text)
            .font(CIQFont.footnote)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var orDivider: some View {
        HStack(spacing: CIQSpacing.sm) {
            Rectangle().fill(CIQColors.Fallback.borderSubtle).frame(height: 0.5)
            Text("or")
                .font(CIQFont.caption)
                .foregroundStyle(CIQColors.Fallback.textTertiary)
            Rectangle().fill(CIQColors.Fallback.borderSubtle).frame(height: 0.5)
        }
    }

    private var appleButton: some View {
        Button(action: signInWithApple) {
            HStack(spacing: CIQSpacing.xs) {
                Image(systemName: "applelogo")
                    .font(.system(size: 18, weight: .medium))
                Text("Sign in with Apple")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: CIQRadius.md))
        }
        .disabled(isWorking)
        .accessibilityLabel("Sign in with Apple")
    }

    // MARK: - Actions

    private func submit() {
        focusedField = nil
        run {
            if isSignUp {
                try await ServiceContainer.shared.auth.signUp(email: email, password: password)
            } else {
                try await ServiceContainer.shared.auth.signIn(email: email, password: password)
            }
        }
    }

    private func signInWithApple() {
        run { try await ServiceContainer.shared.auth.signInWithApple() }
    }

    /// Runs an auth call, routing success to `AppState` and surfacing errors.
    /// `emailConfirmationRequired` is shown as info, not failure.
    private func run(_ operation: @escaping () async throws -> AppUser) {
        isWorking = true
        errorMessage = nil
        infoMessage = nil
        Task {
            do {
                let user = try await operation()
                appState.didSignIn(user)
            } catch SupabaseServiceError.emailConfirmationRequired {
                infoMessage = SupabaseServiceError.emailConfirmationRequired.errorDescription
                isSignUp = false
            } catch {
                if !Self.isCancellation(error) {
                    errorMessage = error.localizedDescription
                }
            }
            isWorking = false
        }
    }

    /// User backing out of the Apple sheet shouldn't read as an error.
    private static func isCancellation(_ error: Error) -> Bool {
        (error as? ASAuthorizationError)?.code == .canceled
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}
