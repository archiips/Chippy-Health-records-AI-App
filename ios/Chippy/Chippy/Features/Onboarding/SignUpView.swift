import SwiftUI

@Observable
@MainActor
final class SignUpViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""
    var isLoading = false
    var errorMessage: String?
    var showError = false

    var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    func signUp(authManager: AuthManager) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AuthService.shared.register(email: email, password: password)
            authManager.signIn(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                userId: response.userId,
                email: response.email
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }
}

struct SignUpView: View {
    @Binding var showSignUp: Bool
    @Environment(AuthManager.self) private var authManager

    @State private var viewModel = SignUpViewModel()
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @FocusState private var focusedField: Field?

    enum Field { case email, password, confirm }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.bottom, 32)

                VStack(spacing: 24) {
                    fields
                    signUpButton
                    signInPrompt
                }
                .padding(.horizontal, 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sign Up Failed", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            LavendorGradientBackground()
                .frame(height: 200)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.lavendorCard)
                        .frame(width: 76, height: 76)
                        .shadow(color: Color.accentColor.opacity(0.2), radius: 16, x: 0, y: 6)

                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }

                Text("Create Account")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.top, 24)
        }
        .frame(height: 200)
        .clipped()
    }

    // MARK: - Fields

    private var fields: some View {
        VStack(spacing: 14) {
            inputField(
                placeholder: "Email",
                text: $viewModel.email,
                keyboardType: .emailAddress,
                contentType: .emailAddress,
                systemImage: "envelope"
            )
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit { focusedField = .password }

            passwordRow(
                placeholder: "Password (8+ characters)",
                text: $viewModel.password,
                contentType: .newPassword,
                isVisible: $showPassword,
                field: .password,
                submitLabel: .next
            ) { focusedField = .confirm }

            VStack(alignment: .leading, spacing: 6) {
                passwordRow(
                    placeholder: "Confirm Password",
                    text: $viewModel.confirmPassword,
                    contentType: .newPassword,
                    isVisible: $showConfirmPassword,
                    field: .confirm,
                    submitLabel: .go
                ) {
                    focusedField = nil
                    Task { await viewModel.signUp(authManager: authManager) }
                }

                if viewModel.passwordMismatch {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.caption)
                        Text("Passwords do not match")
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                    .padding(.leading, 4)
                }
            }
        }
    }

    private func inputField(
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        systemImage: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textContentType(contentType)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.lavendorTint, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
    }

    private func passwordRow(
        placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType,
        isVisible: Binding<Bool>,
        field: Field,
        submitLabel: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)

            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .textContentType(contentType)
            .focused($focusedField, equals: field)
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .foregroundStyle(Color.dimGrey)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.lavendorTint, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Buttons

    private var signUpButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.signUp(authManager: authManager) }
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Create Account")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isLoading || viewModel.passwordMismatch)
    }

    private var signInPrompt: some View {
        HStack(spacing: 4) {
            Text("Already have an account?")
                .foregroundStyle(Color.dimGrey)
            Button("Sign In") {
                showSignUp = false
            }
            .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}
