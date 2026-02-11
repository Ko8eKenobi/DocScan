import SwiftUI

struct DetectionView: View {
    let quad: Quad?
    let image: UIImage

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                if let quad {
                    QuadPath(
                        quad: quad,
                        imageSize: image.size,
                        containerSize: geo.size
                    )
                    .stroke(.yellow, lineWidth: 3)
                }
            }
        }
        .background(.black)
    }
}

private struct QuadPath: Shape {
    let quad: Quad
    let imageSize: CGSize
    let containerSize: CGSize

    func path(in rect: CGRect) -> Path {
        let scale = min(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let xOffset = (containerSize.width - fittedSize.width) / 2
        let yOfsset = (containerSize.height - fittedSize.height) / 2

        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: point.x * scale + xOffset,
                y: point.y * scale + yOfsset
            )
        }

        var path = Path()
        path.move(to: map(quad.topLeft))
        path.addLine(to: map(quad.topRight))
        path.addLine(to: map(quad.bottomRight))
        path.addLine(to: map(quad.bottomLeft))
        path.addLine(to: map(quad.topLeft))
        return path
    }
}
