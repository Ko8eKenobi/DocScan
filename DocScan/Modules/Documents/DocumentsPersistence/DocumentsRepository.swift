import CoreData
import UIKit

protocol IDocumentsRepository {
    func fetch(page: Int, pageSize: Int) async throws -> [Document]
    func fetch(by id: UUID) async throws -> Document?

    func count() async throws -> Int

    func createWithFirstPage(title: String, image: UIImage) async throws -> UUID?

    func saveChanges(doc: Document) async throws

    func delete(id: UUID) async throws
    func deleteAll() async throws

    func exportPDF(_ docID: UUID) async throws -> String
    func getPDFURL(by id: UUID, pdfPath: String) async throws -> URL
}

final class DocumentsRepository: IDocumentsRepository {
    private let persistence: PersistenceController
    private let storageService: IStorageService

    init(persistence: PersistenceController, storageService: IStorageService) {
        self.persistence = persistence
        self.storageService = storageService
    }

    func fetch(page: Int, pageSize: Int) async throws -> [Document] {
        let context = persistence.container.newBackgroundContext()
        return try await context.perform {
            let req = CDDocument.fetchRequest()
            req.sortDescriptors = [
                NSSortDescriptor(keyPath: \CDDocument.createdAt, ascending: false),
            ]
            req.fetchLimit = pageSize
            req.fetchOffset = pageSize * page
            let items = try context.fetch(req)
            return items.compactMap { $0.toDomain() }
        }
    }

    func fetch(by id: UUID) async throws -> Document? {
        let context = persistence.container.viewContext
        return try await context.perform {
            let req = CDDocument.fetchRequest()
            req.fetchLimit = 1
            req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            return try context.fetch(req).first?.toDomain()
        }
    }

    func count() async throws -> Int {
        let context = persistence.container.viewContext
        return try await context.perform {
            let req = CDDocument.fetchRequest()
            return try context.count(for: req)
        }
    }

    func delete(id: UUID) async throws {
        let url = try storageService.docURL(id: id)
        try storageService.removeDoc(by: url)

        let context = persistence.container.newBackgroundContext()
        try await context.perform {
            if let doc = try self.fetchCDDoc(id, in: context) {
                context.delete(doc)
                try context.save()
            }
        }
    }

    func deleteAll() async throws {
        let url = try storageService.docsDirectoryURL()
        try storageService.removeDoc(by: url)

        let context = persistence.container.newBackgroundContext()
        let ids: [NSManagedObjectID] = try await context.perform {
            let req: NSFetchRequest<NSFetchRequestResult> = CDDocument.fetchRequest()
            let batch = NSBatchDeleteRequest(fetchRequest: req)
            batch.resultType = .resultTypeObjectIDs

            let res = try context.execute(batch) as? NSBatchDeleteResult
            return res?.result as? [NSManagedObjectID] ?? []
        }

        let viewContext = persistence.container.viewContext
        NSManagedObjectContext.mergeChanges(
            fromRemoteContextSave: [NSDeletedObjectsKey: ids],
            into: [viewContext]
        )
    }

    func createWithFirstPage(title: String, image: UIImage) async throws -> UUID? {
        let context = persistence.container.newBackgroundContext()
        let pageId = UUID()
        let docId = UUID()

        let imageFileName = "\(pageId.uuidString).jpg"
        let imageThumbFileName = "\(pageId.uuidString)-thumb.jpg"

        let relImagePath = "documents/\(docId.uuidString)/\(imageFileName)"
        let relThumbPath = "documents/\(docId.uuidString)/\(imageThumbFileName)"

        try storageService.saveImage(image: image, docId: docId, fileName: imageFileName, isThumb: false)
        try storageService.saveImage(image: image, docId: docId, fileName: imageThumbFileName, isThumb: true)

        try await context.perform {
            var doc = Document(
                id: docId,
                title: title,
                createdAt: .now,
                status: .draft,
                pdfPath: "",
                previewPath: relThumbPath
            )

            let cdDoc = CDDocument(context: context)
            cdDoc.create(from: doc)

            let page = CDDocumentPage(context: context)
            page.id = pageId
            page.createdAt = .now
            page.index = 0
            page.imagePath = relImagePath
            page.thumbPath = relThumbPath
            page.document = cdDoc

            // Save document preview
            // cdDoc.previewPath = relThumbPath
            cdDoc.status = .ready
            doc.status = .ready
            try context.save()
        }
        return docId
    }

    func saveChanges(doc: Document) async throws {
        let context = persistence.container.newBackgroundContext()
        try await context.perform {
            guard let changeDoc = try self.fetchCDDoc(doc.id, in: context) else { return }
            changeDoc.title = doc.title
            try context.save()
        }
    }

    func exportPDF(_ id: UUID) async throws -> String {
        let context = persistence.container.newBackgroundContext()

        let imagePaths = try await context.perform {
            let pages = try self.fetchPages(id, in: context)
            return pages.compactMap(\.imagePath)
        }

        guard !imagePaths.isEmpty else {
            throw NSError(domain: "Change to custom errors", code: 0, userInfo: nil)
        }

        let pdfPath = "documents/\(id.uuidString)/\(id.uuidString).pdf"

        try await Task.detached(priority: .userInitiated) {
            let images: [UIImage] = try imagePaths.compactMap { path in
                try self.storageService.loadImage(relPath: path)
            }
            guard !images.isEmpty else {
                throw NSError(domain: "PDFExport", code: 2, userInfo: [NSLocalizedDescriptionKey: "No images"])
            }

            try self.storageService.savePDF(images: images, relPath: pdfPath)
        }.value

        try await context.perform {
            guard let doc = try self.fetchCDDoc(id, in: context) else { return }
            doc.pdfPath = pdfPath
            doc.status = .ready
            try context.save()
        }
        return pdfPath
    }

    func getPDFURL(by id: UUID, pdfPath: String) async throws -> URL {
        if !pdfPath.isEmpty {
            let url = try storageService.fileURL(from: pdfPath)
            if storageService.fileExists(url: url) { return url }
        }

        let newPath = try await exportPDF(id)
        guard !newPath.isEmpty else {
            throw NSError(domain: "PDFExport", code: 0, userInfo: [NSLocalizedDescriptionKey: "PDF not generated"])
        }

        return try storageService.fileURL(from: newPath)
    }

    private func baseURL() throws -> URL {
        guard let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "Change to custom errors", code: 0, userInfo: nil)
        }
        return base
    }

    private func fetchCDDoc(_ id: UUID, in context: NSManagedObjectContext) throws -> CDDocument? {
        let request: NSFetchRequest<CDDocument> = CDDocument.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try context.fetch(request).first
    }

    private func fetchPages(_ docID: UUID, in context: NSManagedObjectContext) throws -> [CDDocumentPage] {
        let req: NSFetchRequest<CDDocumentPage> = CDDocumentPage.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(keyPath: \CDDocumentPage.index, ascending: true)]
        req.predicate = NSPredicate(format: "document.id == %@", docID as CVarArg)
        return try context.fetch(req)
    }
}
