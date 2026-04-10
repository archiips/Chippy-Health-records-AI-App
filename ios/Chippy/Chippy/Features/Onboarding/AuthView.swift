import SwiftUI

struct AuthView: View {
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            if showSignUp {
                SignUpView(showSignUp: $showSignUp)
            } else {
                LoginView(showSignUp: $showSignUp)
            }
        }
    }
}
