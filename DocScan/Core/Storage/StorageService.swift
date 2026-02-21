import Foundation
import UIKit

enum StorageError: LocalizedError {
    case documentsDirectoryUnavailable
    case directoryCreationFailed(url: URL, underlying: Error)
    case failedToEncodeJPEG
    case failedToWriteData(url: URL, underlying: Error)
    case imageDecodeFailed(url: URL)
    case pdfNoImages
    case pdfGenerationFailed(url: URL, underlying: Error)
    case invalidRelativePath(String)
    case fileNotFound(url: URL)

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryUnavailable:
            "Documents directory is unavailable."
        case let .directoryCreationFailed(url, _):
            "Failed to create directory: \(url.lastPathComponent)"
        case .failedToEncodeJPEG:
            "Failed to encode JPEG."
        case let .failedToWriteData(url, _):
            "Failed to write file: \(url.lastPathComponent)"
        case let .imageDecodeFailed(url):
            "Failed to decode image: \(url.lastPathComponent)"
        case .pdfNoImages:
            "No images to generate PDF."
        case let .pdfGenerationFailed(url, _):
            "Failed to generate PDF: \(url.lastPathComponent)"
        case let .invalidRelativePath(path):
            "Invalid relative path: \(path)"
        case let .fileNotFound(url):
            "File not found: \(url.lastPathComponent)"
        }
    }
}

protocol IStorageService {
    func docsDirectoryURL() throws -> URL
    func docURL(id: UUID) throws -> URL
    func fileURL(from relPath: String) throws -> URL

    func fileExists(url: URL) -> Bool

    func removeDoc(by url: URL) throws

    func saveImage(image: UIImage, docId: UUID, fileName: String, isThumb: Bool) throws
    func loadImage(relPath: String) throws -> UIImage

    func savePDF(images: [UIImage], relPath: String) throws
    func getPDFURL(by id: UUID) throws -> URL
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

        guard let data else {
            throw StorageError.failedToEncodeJPEG
        }
        do {
            try data.write(to: imageURL, options: [.atomic])
        } catch {
            throw StorageError.failedToWriteData(url: imageURL, underlying: error)
        }
    }

    func loadImage(relPath: String) throws -> UIImage {
        let imgURL = try fileURL(from: relPath)
        guard fileExists(url: imgURL) else {
            throw StorageError.fileNotFound(url: imgURL)
        }

        let image = UIImage(contentsOfFile: imgURL.path)
        guard let image else {
            throw StorageError.imageDecodeFailed(url: imgURL)
        }

        return image
    }

    func savePDF(images: [UIImage], relPath: String) throws {
        guard let first = images.first else {
            throw StorageError.pdfNoImages
        }

        let pdfUrl = try fileURL(from: relPath)
        try createDir(url: pdfUrl.deletingLastPathComponent())

        let pageRect = CGRect(origin: .zero, size: first.size)
        let render = UIGraphicsPDFRenderer(bounds: pageRect)

        do {
            try render.writePDF(to: pdfUrl) { context in
                for img in images {
                    let rect = CGRect(origin: .zero, size: img.size)
                    context.beginPage(withBounds: rect, pageInfo: [:])
                    img.draw(in: rect)
                }
            }
        } catch {
            throw StorageError.pdfGenerationFailed(url: pdfUrl, underlying: error)
        }
    }

    func getPDFURL(by id: UUID) throws -> URL {
        let pdfPath = "documents/\(id.uuidString)/\(id.uuidString).pdf"
        return try fileURL(from: pdfPath)
    }

    func fileExists(url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = fileMngr.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && !isDir.boolValue
    }

    func fileURL(from relPath: String) throws -> URL {
        let trimmed = relPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/") else {
            throw StorageError.invalidRelativePath(relPath)
        }
        return try baseURL().appendingPathComponent(trimmed)
    }

    private func baseURL() throws -> URL {
        guard let base = fileMngr.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw StorageError.documentsDirectoryUnavailable
        }
        return base
    }

    private func fileURL(id: UUID, for fileName: String) throws -> URL {
        try docURL(id: id).appendingPathComponent(fileName)
    }

    private func createDir(url: URL) throws {
        do {
            try fileMngr.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw StorageError.directoryCreationFailed(url: url, underlying: error)
        }
    }
}
