import SwiftUI

struct CameraView: View {
    @State private var capturedImage: UIImage?
    @State private var isReviewing = false
    @State private var detectedQuad: Quad?

    let detector: IQuadDetector
    let onCapture: (UIImage) -> Void

    var body: some View {
        Group {
            if let image = capturedImage, isReviewing {
                VStack {
                    DetectionView(
                        quad: detectedQuad,
                        image: image
                    )
                    HStack {
                        Button("Retake") { retakeDetection() }
                            .buttonStyle(.bordered)
                        Button("Take detected") { takeDetection(detectedQuad, image: image) }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            } else {
                CameraPicker(image: $capturedImage)
                    .onChange(of: capturedImage) { image in
                        guard let image else { return }
                        isReviewing = true
                        Task {
                            detectedQuad = try await detector.detectQuad(in: image)
                        }
                    }
                    .ignoresSafeArea()
            }
        }
        .background(.black)
    }

    private func retakeDetection() {
        resetDetectionState()
    }

    private func takeDetection(_ quad: Quad?, image: UIImage) {
        defer {
            resetDetectionState()
        }
        guard let quad, let doc = try? detector.getImageFromQuad(quad, image: image) else {
            onCapture(image)
            return
        }
        onCapture(doc)
    }

    private func resetDetectionState() {
        capturedImage = nil
        detectedQuad = nil
        isReviewing = false
    }
}
