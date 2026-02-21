import Foundation

public struct Document: Identifiable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
    public var status: DocumentStatus
    public var pdfPath: String
    public let previewPath: String
}

public enum DocumentStatus: String {
    case draft
    case processing
    case ready
    case failed

    // TODO: Check after statuses implementation
    var iconName: String {
        switch self {
        case .draft: "doc"
        case .processing: "arrow.clockwise.circle.fill"
        case .ready: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }
}
