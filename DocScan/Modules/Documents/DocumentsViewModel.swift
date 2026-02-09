import Foundation

@MainActor
final class DocumentsViewModel: ObservableObject {
    @Published private(set) var documents: [Document] = []
    @Published var alert: AppAlert?

    private let repository: DocumentsRepository

    private var page = 0
    private let pageSize = 30
    private var canLoadMore = true

    init(repository: DocumentsRepository) {
        self.repository = repository
    }

    private func load() async {
        page = 0
        canLoadMore = true

        do {
            documents = try await repository.fetch(page: page, pageSize: pageSize)
            canLoadMore = documents.count == pageSize
        } catch {
            alert = AppAlert(title: "Failed to load documents", message: error.localizedDescription)
        }
    }

    func onAppear() async {
        if documents.isEmpty {
            await load()
        }
    }

    func addMockDocument() async {
        do {
            _ = try await repository.createMock()
            await load()
        } catch {
            alert = AppAlert(title: "Failed to add Mock Document", message: error.localizedDescription)
        }
    }

    func refreshDocuments() async {
        await load()
    }

    func deleteDocument(at offsets: IndexSet) async {
        let ids = offsets.map { self.documents[$0].id }
        do {
            for id in ids {
                try await repository.delete(id: id)
            }
            await load()
        } catch {
            alert = AppAlert(title: "Failed to delete", message: error.localizedDescription)
        }
    }

    func deleteAll() async {
        do {
            try await repository.deleteAll()
            await load()
        } catch {
            alert = AppAlert(title: "Failed to delete all", message: error.localizedDescription)
        }
    }

    func loadMore(currentId: UUID) async {
        guard canLoadMore else {
            return
        }
        guard let lastId = documents.last?.id, lastId == currentId else { return }

        do {
            page += 1
            let next = try await repository.fetch(page: page, pageSize: pageSize)
            documents.append(contentsOf: next)
            canLoadMore = next.count == pageSize
        } catch {
            // TODO: No alert, just log + soft retry
            alert = AppAlert(title: "Failed to load more documents", message: error.localizedDescription)
        }
    }
}
