import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss)
    private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return picker
        }
        picker.sourceType = .camera
        picker.cameraDevice = .rear
        picker.modalPresentationStyle = .fullScreen
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [
                UIImagePickerController.InfoKey: Any
            ]
        ) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
    }
}
