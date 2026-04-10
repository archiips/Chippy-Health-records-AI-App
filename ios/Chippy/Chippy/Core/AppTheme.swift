import SwiftUI

extension Color {
    /// Dim grey (#6F6E6A) — use for secondary labels and icons.
    static let dimGrey = Color(red: 0.435, green: 0.431, blue: 0.416)
}

/// Gradient from lavender card at the top to the system background in the center.
/// Use on full-screen views like onboarding and lock screen.
struct LavendorGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.lavendorCard, Color(.systemBackground)],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }
}
