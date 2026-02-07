import Foundation

@MainActor
final class DocumentsViewModel: ObservableObject {
    @Published private(set) var documents: [Document] = []
    
    private let repository: DocumentsRepository
    
    private var page = 0
    private let pageSize = 30
    private var canLoadMore = true
    
    init(repository: DocumentsRepository){
        self.repository = repository
    }
    
    private func load() async {
        page = 0
        canLoadMore = true
        
        do {
            documents = try await repository.fetch(page: page, pageSize: pageSize)
            canLoadMore = documents.count == pageSize
        } catch {
            //TODO: error state + retry
            AppLogger.repository.debug("Failed to load documents: \(error)")
            documents = []
        }
    }
    
    func onAppear() async {
        if documents.isEmpty {
            await load()
        }
    }
    
    func addMockDocument() async {
        do{
            _ = try await repository.createMock()
            await load()
        } catch {
            AppLogger.repository.error("\(error.localizedDescription)")
        }
    }
    
    func refreshDocuments() async {
        await load()
    }
    
    func deleteDocument(at offsets: IndexSet) async {
        let ids = offsets.map { documents[$0].id }
        for id in ids {
            try? await repository.delete(id: id)
        }
        await load()
    }
    
    func deleteAll() async {
        try? await repository.deleteAll()
        await load()
    }
    
    func loadMore(currentId: UUID) async {
        guard canLoadMore else { return }
        guard let lastId = documents.last?.id, lastId == currentId else { return }
        do {
            AppLogger.repository.debug("New page loading...")
            page += 1
            let next = try await repository.fetch(page: page, pageSize: pageSize)
            documents.append(contentsOf: next)
            canLoadMore = next.count == pageSize
        } catch {
            // TODO: Error handling
        }
    }
}
