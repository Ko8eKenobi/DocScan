import Foundation
import UIKit

protocol IStorageService {
    func docsDirectoryURL() throws -> URL
    func docURL(id: UUID) throws -> URL
    func fileURL(from relPath: String) throws -> URL
    func fileExists(url: URL) -> Bool

    func removeDoc(by url: URL) throws

    func saveImage(image: UIImage, docId: UUID, fileName: String, isThumb: Bool) throws
    func loadImage(relPath: String) throws -> UIImage?

    func savePDF(images: [UIImage], relPath: String) throws
    func getPDFURL(by id: UUID) async throws -> URL
}

final class StorageService: IStorageService {
    private let fileMngr = FileManager.default

    func docsDirectoryURL() throws -> URL {
        try baseURL().appendingPathComponent("documents", isDirectory: true)
    }

    func docURL(id: UUID) throws -> URL {
        try docsDirectoryURL()
            .appendingPathComponent(id.uuidString, isDirectory: true)
    }

    func removeDoc(by url: URL) throws {
        if fileMngr.fileExists(atPath: url.path) {
            try fileMngr.removeItem(at: url)
        }
    }

    func saveImage(image: UIImage, docId: UUID, fileName: String, isThumb: Bool) throws {
        var data: Data?
        let url = try docURL(id: docId)
        try createDir(url: url)

        let imageURL = try fileURL(id: docId, for: fileName)

        if isThumb {
            let size = image.size
            let scale = 240.0 / max(size.width, size.height)
            let target = CGSize(width: size.width * scale, height: size.height * scale)

            let renderer = UIGraphicsImageRenderer(size: target)
            let thumb = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }
            data = thumb.jpegData(compressionQuality: 0.8)
        } else {
            data = image.jpegData(compressionQuality: 1)
        }
        try data?.write(to: imageURL)
    }

    func loadImage(relPath: String) throws -> UIImage? {
        let imgURL = try fileURL(from: relPath)
        return UIImage(contentsOfFile: imgURL.path)
    }

    func savePDF(images: [UIImage], relPath: String) throws {
        guard let first = images.first else {
            throw NSError(domain: "PDFExport", code: 10, userInfo: [NSLocalizedDescriptionKey: "No images"])
        }

        let pdfUrl = try fileURL(from: relPath)

        try createDir(url: pdfUrl.deletingLastPathComponent())

        let pageRect = CGRect(origin: .zero, size: first.size)

        let render = UIGraphicsPDFRenderer(bounds: pageRect)

        try render.writePDF(to: pdfUrl) { context in
            for img in images {
                let rect = CGRect(origin: .zero, size: img.size)
                context.beginPage(withBounds: rect, pageInfo: [:])
                img.draw(in: rect)
            }
        }
    }

    func getPDFURL(by id: UUID) async throws -> URL {
        let pdfPath = "documents/\(id.uuidString)/\(id.uuidString).pdf"
        return try fileURL(from: pdfPath)
    }

    func fileExists(url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = fileMngr.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && !isDir.boolValue
    }

    private func baseURL() throws -> URL {
        guard let base = fileMngr.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "Change to custom errors", code: 0, userInfo: nil)
        }
        return base
    }

    private func fileURL(id: UUID, for fileName: String) throws -> URL {
        try docURL(id: id).appendingPathComponent(fileName)
    }

    func fileURL(from relPath: String) throws -> URL {
        try baseURL().appendingPathComponent(relPath)
    }

    private func createDir(url: URL) throws {
        try fileMngr.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }
}
