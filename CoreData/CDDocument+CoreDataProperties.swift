import CoreData
import Foundation

public extension CDDocument {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CDDocument> {
        NSFetchRequest<CDDocument>(entityName: "CDDocument")
    }

    @NSManaged var createdAt: Date?
    @NSManaged var id: UUID?
    @NSManaged var pdfPath: String?
    @NSManaged var previewPath: String?
    @NSManaged var statusRaw: String?
    @NSManaged var title: String?
    @NSManaged var pages: NSOrderedSet?
}

// MARK: Generated accessors for pages

public extension CDDocument {
    @objc(insertObject:inPagesAtIndex:)
    @NSManaged func insertIntoPages(_ value: CDDocumentPage, at idx: Int)

    @objc(removeObjectFromPagesAtIndex:)
    @NSManaged func removeFromPages(at idx: Int)

    @objc(insertPages:atIndexes:)
    @NSManaged func insertIntoPages(_ values: [CDDocumentPage], at indexes: NSIndexSet)

    @objc(removePagesAtIndexes:)
    @NSManaged func removeFromPages(at indexes: NSIndexSet)

    @objc(replaceObjectInPagesAtIndex:withObject:)
    @NSManaged func replacePages(at idx: Int, with value: CDDocumentPage)

    @objc(replacePagesAtIndexes:withPages:)
    @NSManaged func replacePages(at indexes: NSIndexSet, with values: [CDDocumentPage])

    @objc(addPagesObject:)
    @NSManaged func addToPages(_ value: CDDocumentPage)

    @objc(removePagesObject:)
    @NSManaged func removeFromPages(_ value: CDDocumentPage)

    @objc(addPages:)
    @NSManaged func addToPages(_ values: NSOrderedSet)

    @objc(removePages:)
    @NSManaged func removeFromPages(_ values: NSOrderedSet)
}

extension CDDocument: Identifiable {}
