import CoreData
import Foundation

public extension CDDocumentPage {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CDDocumentPage> {
        NSFetchRequest<CDDocumentPage>(entityName: "CDDocumentPage")
    }

    @NSManaged var id: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var imagePath: String?
    @NSManaged var index: Int32
    @NSManaged var thumbPath: String?
    @NSManaged var document: CDDocument?
}

extension CDDocumentPage: Identifiable {}
