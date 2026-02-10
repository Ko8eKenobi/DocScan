import Foundation
import UIKit

@MainActor
final class DocumentsViewModel: ObservableObject {
    @Published private(set) var documents: [Document] = []
    @Published var alert: AppAlert?

    private let repository: IDocumentsRepository

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

    // TODO: Improve default document title generation
    private func makeTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "Scan yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: .now)
    }

    func onAppear() async {
        if documents.isEmpty {
            await load()
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

    func deleteDocument(by id: UUID) async {
        do {
            try await repository.delete(id: id)
            documents.removeAll { $0.id == id }
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

    func createDocument(from image: UIImage) async -> UUID? {
        do {
            let title = makeTitle()
            let id = try await repository.createWithFirstPage(title: title, image: image)
            await load()
            return id
        } catch {
            alert = AppAlert(title: "Failed create document", message: error.localizedDescription)
            return nil
        }
    }
}
