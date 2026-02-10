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
}

final class DocumentsRepository: IDocumentsRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
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
        guard let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "FileStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "No documents directory"])
        }
        let dir = base
            .appendingPathComponent("documents", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)

        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }

        let context = persistence.container.newBackgroundContext()
        return try await context.perform {
            let req: NSFetchRequest<CDDocument> = CDDocument.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let doc = try context.fetch(req).first {
                context.delete(doc)
                try context.save()
            }
        }
    }

    func deleteAll() async throws {
        guard let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "FileStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "No documents directory"])
        }
        let dir = base.appendingPathComponent("documents", isDirectory: true)

        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }

        let context = persistence.container.newBackgroundContext()
        let ids: [NSManagedObjectID] = try await context.perform {
            let req = NSFetchRequest<NSFetchRequestResult>(entityName: "CDDocument")
            let batch = NSBatchDeleteRequest(fetchRequest: req)

            batch.resultType = .resultTypeObjectIDs

            let res = try context.execute(batch) as? NSBatchDeleteResult
            return res?.result as? [NSManagedObjectID] ?? []
        }
        let viewContext = persistence.container.viewContext
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: ids], into: [viewContext])
    }

    // TODO: Refactor with StorageHandler
    func createWithFirstPage(title: String, image: UIImage) async throws -> UUID? {
        let context = persistence.container.newBackgroundContext()
        var result: UUID?

        try await context.perform {
            var doc = Document(
                id: UUID(),
                title: title,
                createdAt: .now,
                status: .draft,
                pdfPath: "",
                previewPath: ""
            )
            // TODO: Clean up debug comments after stabilizing file paths
            // Create directory
            let cdDoc = CDDocument(context: context)
            cdDoc.create(from: doc)

            guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let url = dir
                .appendingPathComponent("documents", isDirectory: true)
                .appendingPathComponent(doc.id.uuidString, isDirectory: true)

            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

            // Save images
            let pageId = UUID()
            let relImagePath = "documents/\(doc.id.uuidString)/\(pageId.uuidString).jpg"
            let relThumbPath = "documents/\(doc.id.uuidString)/\(pageId.uuidString)-thumb.jpg"

            guard let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let imageURL = base.appendingPathComponent(relImagePath)
            let thumbURL = base.appendingPathComponent(relThumbPath)

            let imageData = image.jpegData(compressionQuality: 1)
            try imageData?.write(to: imageURL)

            let size = image.size
            let scale = 240.0 / max(size.width, size.height)
            let target = CGSize(width: size.width * scale, height: size.height * scale)

            let renderer = UIGraphicsImageRenderer(size: target)
            let thumb = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }

            guard let thumbImage = thumb.jpegData(compressionQuality: 0.8) else { return }
            try thumbImage.write(to: thumbURL)

            // Create page with links to document
            let page = CDDocumentPage(context: context)
            page.id = pageId
            page.createdAt = Date()
            page.index = 0
            page.imagePath = relImagePath
            page.thumbPath = relThumbPath
            page.document = cdDoc

            // Save document preview
            cdDoc.previewPath = relThumbPath
            cdDoc.status = .ready
            doc.status = .ready
            try context.save()
            result = doc.id
        }
        return result
    }

    func saveChanges(doc: Document) async throws {
        let context = persistence.container.newBackgroundContext()
        try await context.perform {
            let req: NSFetchRequest<CDDocument> = CDDocument.fetchRequest()
            req.fetchLimit = 1
            req.predicate = NSPredicate(format: "id == %@", doc.id as CVarArg)

            guard let changeDoc = try context.fetch(req).first else { return }
            changeDoc.title = doc.title
            try context.save()
        }
    }
}
