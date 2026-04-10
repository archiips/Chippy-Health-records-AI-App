import SwiftUI

struct ProcessingStatusBadge: View {
    let status: ProcessingStatus

    var body: some View {
        switch status {
        case .processing:
            PhaseAnimator([1.0, 0.4], trigger: status) { opacity in
                Image(systemName: "ellipsis.circle.fill")
                    .foregroundStyle(.orange)
                    .opacity(opacity)
            } animation: { _ in .easeInOut(duration: 0.8) }
            .accessibilityLabel("Processing")

        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Complete")

        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("Processing failed")
        }
    }
}
