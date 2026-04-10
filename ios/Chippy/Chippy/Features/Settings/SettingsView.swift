import SwiftUI
import SwiftData
import LocalAuthentication

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(AppLockManager.self) private var lockManager
    @Environment(\.modelContext) private var context

    @AppStorage("faceIDEnabled") private var faceIDEnabled = true
    @State private var showSignOutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                securitySection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog("Sign out?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { authManager.signOut() }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Delete all your data?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    Task { await deleteAllData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all your uploaded documents, analysis, and chat history from Chippy. This cannot be undone.")
            }
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section("Account") {
            if let email = authManager.email {
                LabeledContent("Email", value: email)
            }
            Button("Sign Out", role: .destructive) {
                showSignOutConfirmation = true
            }
        }
    }

    private var securitySection: some View {
        Section("Security") {
            Toggle(isOn: $faceIDEnabled) {
                Label(
                    lockManager.biometryType == .faceID ? "Face ID Lock" : "Touch ID Lock",
                    systemImage: lockManager.biometryType == .faceID ? "faceid" : "touchid"
                )
            }
            .onChange(of: faceIDEnabled) { _, enabled in
                if !enabled { lockManager.lock() }
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                if isDeleting {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Deleting…")
                    }
                } else {
                    Label("Delete All My Data", systemImage: "trash")
                }
            }
            .disabled(isDeleting)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            VStack(alignment: .leading, spacing: 4) {
                Text("Not Medical Advice")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Chippy is for informational purposes only. It is not a substitute for professional medical advice, diagnosis, or treatment.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Actions

    private func deleteAllData() async {
        guard let token = await authManager.validToken() else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            // Call backend to delete server-side data
            var request = URLRequest(url: Constants.baseURL.appendingPathComponent("/auth/account"))
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 204 else {
                throw URLError(.badServerResponse)
            }
        } catch {
            errorMessage = "Could not delete server data: \(error.localizedDescription)"
            return
        }

        // Clear local SwiftData
        try? context.delete(model: HealthDocument.self)
        try? context.delete(model: AnalysisResult.self)
        try? context.delete(model: HealthEvent.self)
        try? context.delete(model: ChatMessage.self)
        try? context.save()

        // Sign out
        authManager.signOut()
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
