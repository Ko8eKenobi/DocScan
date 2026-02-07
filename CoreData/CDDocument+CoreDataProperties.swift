//
//  CDDocument+CoreDataProperties.swift
//  DocScan
//
//  Created by Denis Shishmarev on 07.02.2026.
//
//

import Foundation
import CoreData


extension CDDocument {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDDocument> {
        return NSFetchRequest<CDDocument>(entityName: "CDDocument")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var pdfPath: String?
    @NSManaged public var previewPath: String?
    @NSManaged public var statusRaw: String?
    @NSManaged public var title: String?

}

extension CDDocument : Identifiable {

}
