import SwiftUI

struct CameraView: View {
    @State private var capturedImage: UIImage?

    let onCapture: (UIImage) -> Void

    var body: some View {
        CameraPicker(image: $capturedImage)
            .onChange(of: capturedImage) { image in
                guard let image else { return }
                onCapture(image)
                capturedImage = nil
            }
            .ignoresSafeArea()
    }
}
