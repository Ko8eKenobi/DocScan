import Foundation

@MainActor
final class DocumentDetailsViewModel: ObservableObject {
    @Published private(set) var document: Document?
    @Published var alert: AppAlert?

    private let repository: DocumentsRepository
    private let id: UUID

    init(id: UUID, repository: DocumentsRepository) {
        self.id = id
        self.repository = repository
    }

    func onAppear() async {
        guard document == nil else { return }
        await load()
    }

    private func load() async {
        do {
            document = try await repository.fetch(by: id)
        } catch {
            alert = AppAlert(title: "Failed to load", message: error.localizedDescription)
        }
    }
}
