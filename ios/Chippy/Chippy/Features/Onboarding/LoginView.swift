import SwiftUI

@Observable
@MainActor
final class LoginViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?
    var showError = false

    func login(authManager: AuthManager) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AuthService.shared.login(email: email, password: password)
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

struct LoginView: View {
    @Binding var showSignUp: Bool
    @Environment(AuthManager.self) private var authManager

    @State private var viewModel = LoginViewModel()
    @State private var showPassword = false
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.bottom, 40)

                VStack(spacing: 24) {
                    fields
                    loginButton
                    signUpPrompt
                }
                .padding(.horizontal, 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sign In Failed", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            LavendorGradientBackground()
                .frame(height: 260)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.lavendorCard)
                        .frame(width: 88, height: 88)
                        .shadow(color: Color.accentColor.opacity(0.2), radius: 16, x: 0, y: 6)

                    Image(systemName: "heart.text.clipboard")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 4) {
                    Text("Welcome back")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Your health history, finally clear.")
                        .font(.subheadline)
                        .foregroundStyle(Color.dimGrey)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 32)
        }
        .frame(height: 260)
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

            ZStack(alignment: .trailing) {
                inputField(
                    placeholder: "Password",
                    text: $viewModel.password,
                    isSecure: !showPassword,
                    contentType: .password,
                    systemImage: "lock"
                )
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit {
                    focusedField = nil
                    Task { await viewModel.login(authManager: authManager) }
                }
                .padding(.trailing, 44)

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(Color.dimGrey)
                }
                .padding(.trailing, 16)
            }
        }
    }

    private func inputField(
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        systemImage: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboardType)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .textContentType(contentType)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.lavendorTint, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Buttons

    private var loginButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.login(authManager: authManager) }
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Sign In")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isLoading)
    }

    private var signUpPrompt: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .foregroundStyle(Color.dimGrey)
            Button("Sign Up") {
                showSignUp = true
            }
            .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}
