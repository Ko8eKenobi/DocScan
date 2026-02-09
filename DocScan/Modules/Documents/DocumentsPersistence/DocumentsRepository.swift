import CoreData
import UIKit

protocol IDocumentsRepository {
    func fetch(page: Int, pageSize: Int) async throws -> [Document]
    func fetch(by id: UUID) async throws -> Document?

    func count() async throws -> Int

    // func create(title: String) async throws -> Document

    func delete(id: UUID) async throws
    func deleteAll() async throws
}

final class DocumentsRepository: IDocumentsRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func fetch(page: Int, pageSize: Int) async throws -> [Document] {
        // TODO: Consider to use background context
        let context = persistence.container.viewContext
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

//    private func create(title: String) async throws -> Document {
//        let context = persistence.container.viewContext
//        return try await context.perform {
//            let doc = Document(
//                id: UUID(),
//                title: title,
//                createdAt: .now,
//                status: .draft,
//                pdfPath: "",
//                previewPath: ""
//            )
//            let cd = CDDocument(context: context)
//            cd.create(from: doc)
//            try context.save()
//            return doc
//        }
//    }

    func delete(id: UUID) async throws {
        let context = persistence.container.viewContext
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
        let context = persistence.container.viewContext
        try await context.perform {
            let req = NSFetchRequest<NSFetchRequestResult>(entityName: "CDDocument")
            let batch = NSBatchDeleteRequest(fetchRequest: req)

            batch.resultType = .resultTypeObjectIDs

            let res = try context.execute(batch) as? NSBatchDeleteResult
            let ids = res?.result as? [NSManagedObjectID] ?? []

            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: ids], into: [context])
        }
    }

    // TODO: Refactor with StorageHandler
    func createWithFirstPage(title: String, image: UIImage) async throws -> UUID? {
        let context = persistence.container.viewContext
        var result: UUID?

        try await context.perform {
            let doc = Document(
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

            // TODO: Switch to relative paths in CoreData (avoid storing sandbox absolute paths)
            guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let url = dir.appendingPathComponent("documents", isDirectory: true)
                .appendingPathComponent(doc.id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

            // Save images
            let pageId = UUID()
            let imageURL = url.appendingPathComponent("\(pageId.uuidString).jpg")
            let thumbURL = url.appendingPathComponent("\(pageId.uuidString)-thumb.jpg")

            let imageData = image.jpegData(compressionQuality: 1)
            try imageData?.write(to: imageURL)

            let size = image.size
            let scale = 240.0 / max(size.width, size.height)
            let target = CGSize(width: size.width * scale, height: size.height * scale)

            let render = UIGraphicsImageRenderer(size: target)
            let thumb = render.image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }

            guard let thumbImage = thumb.jpegData(compressionQuality: 0.8) else { return }
            try thumbImage.write(to: thumbURL)

            // Create page with links to document
            let page = CDDocumentPage(context: context)
            page.id = pageId
            page.createdAt = Date()
            page.index = 0
            page.imagePath = imageURL.path
            page.thumbPath = thumbURL.path
            page.document = cdDoc

            // Save document preview
            cdDoc.previewPath = thumbURL.path

            try context.save()
            result = doc.id
        }
        return result
    }
}
