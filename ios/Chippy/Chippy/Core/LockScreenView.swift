import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    @Environment(AppLockManager.self) private var lockManager

    var body: some View {
        ZStack {
            LavendorGradientBackground()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.lavendorCard)
                            .frame(width: 100, height: 100)
                            .shadow(color: Color.accentColor.opacity(0.2), radius: 20, x: 0, y: 8)

                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(spacing: 6) {
                        Text("Chippy")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Your health history, finally clear.")
                            .font(.subheadline)
                            .foregroundStyle(Color.dimGrey)
                    }
                }

                Spacer()

                Button {
                    Task { await lockManager.authenticate() }
                } label: {
                    Label(
                        lockManager.biometryType == .faceID ? "Unlock with Face ID" :
                        lockManager.biometryType == .touchID ? "Unlock with Touch ID" : "Unlock",
                        systemImage: lockManager.biometryType == .faceID ? "faceid" :
                        lockManager.biometryType == .touchID ? "touchid" : "lock.open"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
        .task { await lockManager.authenticate() }
    }
}
