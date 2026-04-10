import SwiftUI
import PhotosUI

struct PhotoPicker: UIViewControllerRepresentable {
    let onCompletion: (UIImage) -> Void
    let onCancellation: () -> Void

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
        Coordinator(onCompletion: onCompletion, onCancellation: onCancellation)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onCompletion: (UIImage) -> Void
        let onCancellation: () -> Void

        init(onCompletion: @escaping (UIImage) -> Void, onCancellation: @escaping () -> Void) {
            self.onCompletion = onCompletion
            self.onCancellation = onCancellation
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { onCancellation(); return }
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                Task { @MainActor in self.onCompletion(image) }
            }
        }
    }
}
