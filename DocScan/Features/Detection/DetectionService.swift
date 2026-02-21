import UIKit
import Vision

enum DetectionError: Error {
    case failedToCreateCGImage
    case failedToGetDocumentFromImage
}

protocol IQuadDetector {
    func detectQuad(in image: UIImage) async throws -> Quad?
    func getImageFromQuad(_ quad: Quad, image: UIImage) throws -> UIImage
}

final class QuadDetector: IQuadDetector {
    let context = CIContext(options: nil)

    func detectQuad(in image: UIImage) async throws -> Quad? {
        guard let cgImage = image.cgImage else {
            throw DetectionError.failedToCreateCGImage
        }

        let orientation = cgOrientation(from: image.imageOrientation)

        let request = VNDetectRectanglesRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        try handler.perform([request])

        guard let observations = (request.results)?.first else { throw DetectionError.failedToCreateCGImage }

        let oriented = CIImage(cgImage: cgImage).oriented(orientation)

        let width = oriented.extent.width
        let height = oriented.extent.height

        return Quad(
            topLeft: convert(observations.topLeft),
            topRight: convert(observations.topRight),
            bottomRight: convert(observations.bottomRight),
            bottomLeft: convert(observations.bottomLeft)
        )
        func convert(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: point.x * width,
                y: (1 - point.y) * height
            )
        }
    }

    func getImageFromQuad(_ quad: Quad, image: UIImage) throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw DetectionError.failedToGetDocumentFromImage
        }
        let orientation = cgOrientation(from: image.imageOrientation)
        let base = CIImage(cgImage: cgImage)
        let oriented = base.oriented(orientation)

        let scale = image.scale

        let height = oriented.extent.height

        func flip(_ point: CGPoint) -> CGPoint {
            let scaled = CGPoint(x: point.x * scale, y: point.y * scale)
            return CGPoint(x: scaled.x, y: height - scaled.y)
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            throw DetectionError.failedToGetDocumentFromImage
        }

        filter.setValue(oriented, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: flip(quad.topLeft)), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: flip(quad.topRight)), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: flip(quad.bottomRight)), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: flip(quad.bottomLeft)), forKey: "inputBottomLeft")

        guard let output = filter.outputImage,
              let cg = context.createCGImage(output, from: output.extent)
        else { return image }

        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
    }

    private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
