import SwiftUI

/// A shimmering placeholder rectangle used for skeleton loading states.
struct SkeletonView: View {
    var cornerRadius: CGFloat = 8
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Color.lavendorCard, location: phase - 0.4),
                        .init(color: Color.lavendorTint, location: phase),
                        .init(color: Color.lavendorCard, location: phase + 0.4),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

/// A row-shaped skeleton for use in list loading states.
struct SkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView(cornerRadius: 8)
                .frame(width: 56, height: 72)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView().frame(height: 14)
                SkeletonView(cornerRadius: 10).frame(width: 80, height: 18)
            }
        }
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }
}
