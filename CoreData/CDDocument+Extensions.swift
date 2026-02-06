import Foundation
import CoreData

extension CDDocument {
    var status: DocumentStatus {
        get { DocumentStatus(rawValue: statusRaw ?? DocumentStatus.draft.rawValue) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }
    
    func toDomain() -> Document? {
        Document(
            id: id ?? UUID(),
            title: title ?? "",
            createdAt: createdAt ?? Date(),
            status: status,
            pdfPath: pdfPath ?? "",
            previewPath: previewPath ?? ""
        )
    }
    
    func create(from doc: Document){
        id = doc.id
        title = doc.title
        createdAt = doc.createdAt
        status = doc.status
        statusRaw = doc.status.rawValue
        pdfPath = doc.pdfPath
        previewPath = doc.previewPath
    }
}
