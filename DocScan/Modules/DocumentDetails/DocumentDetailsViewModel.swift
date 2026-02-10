import Foundation

@MainActor
final class DocumentDetailsViewModel: ObservableObject {
    @Published private(set) var document: Document?
    @Published var alert: AppAlert?

    private let repository: IDocumentsRepository
    private let id: UUID

    init(id: UUID, repository: IDocumentsRepository) {
        self.id = id
        self.repository = repository
    }

    private func load() async {
        do {
            document = try await repository.fetch(by: id)
        } catch {
            alert = AppAlert(title: "Failed to load", message: error.localizedDescription)
        }
    }

    func onAppear() async {
        guard document == nil else { return }
        await load()
    }

    func rename(to newTitle: String) async {
        guard var doc = document else { return }

        do {
            doc.title = newTitle
            document = doc
            try await repository.saveChanges(doc: doc)
        } catch {
            alert = AppAlert(title: "Rename failed", message: error.localizedDescription)
        }
    }
}
