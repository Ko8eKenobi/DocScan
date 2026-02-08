//
//  CDDocument+CoreDataProperties.swift
//  DocScan
//
//  Created by Denis Shishmarev on 07.02.2026.
//
//

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
}

extension CDDocument: Identifiable {}
