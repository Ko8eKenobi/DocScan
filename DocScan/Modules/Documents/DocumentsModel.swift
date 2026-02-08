import Foundation

public struct Document: Identifiable {
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public var status: DocumentStatus
    public let pdfPath: String
    public let previewPath: String
}

public enum DocumentStatus: String {
    case draft
    case processing
    case ready
    case failed
}
