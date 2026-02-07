import CoreData

protocol IDocumentsRepository {
    func fetch(page: Int, pageSize: Int) async throws -> [Document]
    func count() async throws -> Int

    func createMock() async throws -> Document
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
                NSSortDescriptor(keyPath: \CDDocument.createdAt, ascending: false)
            ]
            req.fetchLimit = pageSize
            req.fetchOffset = pageSize * page
            let items = try context.fetch(req)
            return items.compactMap{ $0.toDomain() }
        }
        
    }
    
    func count() async throws -> Int {
        let context = persistence.container.viewContext
        return try await context.perform {
            let req = CDDocument.fetchRequest()
            return try context.count(for: req)
        }
    }
    
    func createMock() async throws -> Document {
        let context = persistence.container.viewContext
        return try await context.perform {
            let doc = Document(
                id: UUID(),
                title: "Some Title \((1...20).randomElement() ?? 0)",
                createdAt: .now,
                status: .draft,
                pdfPath: "",
                previewPath: ""
            )
            let cd = CDDocument(context: context)
            cd.create(from: doc)
            try context.save()
            return doc
        }
    }
    
    func delete(id: UUID) async throws {
        let context = persistence.container.viewContext
        return try await context.perform {
            let req: NSFetchRequest<CDDocument> = CDDocument.fetchRequest()
            req.predicate = NSPredicate(format: "id == %@", id.uuidString)
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
    
    
}
