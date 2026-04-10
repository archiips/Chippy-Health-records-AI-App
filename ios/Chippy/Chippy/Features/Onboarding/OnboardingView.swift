import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "heart.text.square.fill",
            title: "Your health history,\nfinally clear.",
            body: "Chippy turns confusing medical documents into a searchable health timeline explained in plain language."
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            title: "Your data stays private.",
            body: "Text is extracted on your device before anything is sent to the server. Your documents are stored securely and never shared or sold."
        ),
        OnboardingPage(
            icon: "doc.text.magnifyingglass",
            title: "Ask anything about\nyour records.",
            body: "Upload a lab result, prescription, or visit note — then ask questions in plain English. Chippy reads your documents so you don't have to."
        ),
    ]

    var body: some View {
        ZStack {
            LavendorGradientBackground()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, p in
                        pageView(p).tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: page)

                bottomBar
                    .padding(.bottom, 52)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 20) {
            // Dot indicator
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Color.accentColor : Color.accentColor.opacity(0.25))
                        .frame(width: i == page ? 20 : 8, height: 8)
                        .animation(.spring(duration: 0.3), value: page)
                }
            }

            if page < pages.count - 1 {
                HStack {
                    Button("Skip") { onComplete() }
                        .font(.subheadline)
                        .foregroundStyle(Color.dimGrey)
                    Spacer()
                    Button {
                        withAnimation { page += 1 }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 32)
            } else {
                Button(action: onComplete) {
                    Text("Get Started")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)
            }
        }
    }

    private func pageView(_ p: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon in a circle
            ZStack {
                Circle()
                    .fill(Color.lavendorCard)
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.accentColor.opacity(0.2), radius: 20, x: 0, y: 8)

                Image(systemName: p.icon)
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 14) {
                Text(p.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(p.body)
                    .font(.body)
                    .foregroundStyle(Color.dimGrey)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Spacer()
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let body: String
}
