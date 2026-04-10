import SwiftUI
import UniformTypeIdentifiers

struct FilePicker: UIViewControllerRepresentable {
    let onCompletion: (URL) -> Void
    let onCancellation: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion, onCancellation: onCancellation)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onCompletion: (URL) -> Void
        let onCancellation: () -> Void

        init(onCompletion: @escaping (URL) -> Void, onCancellation: @escaping () -> Void) {
            self.onCompletion = onCompletion
            self.onCancellation = onCancellation
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onCompletion(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancellation()
        }
    }
}
