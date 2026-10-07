import SwiftUI

struct AuthView: View {
    @Environment(ProcessingPreferences.self) private var preferences
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            Group {
            if showSignUp {
                SignUpView(showSignUp: $showSignUp)
            } else {
                LoginView(showSignUp: $showSignUp)
            }
            }
            .toolbar { Button("Use Local Records") { preferences.useLocal() } }
        }
    }
}
