import SwiftUI
import PhotosUI

struct PhotoPicker: UIViewControllerRepresentable {
    let onCompletion: (UIImage) -> Void
    let onCancellation: () -> Void
    var onFailure: ((String) -> Void)? = nil
    var onLoading: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion, onCancellation: onCancellation, onFailure: onFailure, onLoading: onLoading)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onCompletion: (UIImage) -> Void
        let onCancellation: () -> Void

        let onFailure: ((String) -> Void)?
        let onLoading: (() -> Void)?

        init(onCompletion: @escaping (UIImage) -> Void, onCancellation: @escaping () -> Void,
             onFailure: ((String) -> Void)? = nil, onLoading: (() -> Void)? = nil) {
            self.onCompletion = onCompletion
            self.onCancellation = onCancellation
            self.onFailure = onFailure
            self.onLoading = onLoading
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { onCancellation(); return }
            loadImage(from: result.itemProvider)
        }

        func loadImage(from provider: NSItemProvider) {
            onLoading?()
            guard provider.canLoadObject(ofClass: UIImage.self) else { reportFailure(); return }
            provider.loadObject(ofClass: UIImage.self) { object, error in
                let image = object as? UIImage
                Task { @MainActor in
                    guard error == nil, let image else { self.reportFailure(); return }
                    self.onCompletion(image)
                }
            }
        }

        private func reportFailure() {
            if let onFailure { onFailure("The selected photo could not be loaded. Open it in Photos to download it, or choose another image, then try again.") }
            else { onCancellation() }
        }
    }
}
