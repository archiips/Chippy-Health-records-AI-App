import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    let onCompletion: ([UIImage]) -> Void
    let onCancellation: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion, onCancellation: onCancellation)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onCompletion: ([UIImage]) -> Void
        let onCancellation: () -> Void

        init(onCompletion: @escaping ([UIImage]) -> Void, onCancellation: @escaping () -> Void) {
            self.onCompletion = onCompletion
            self.onCancellation = onCancellation
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            onCompletion(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancellation()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onCancellation()
        }
    }
}
