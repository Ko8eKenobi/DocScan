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

    func exportPDF() async {
        guard let doc = document else { return }
        do {
            let pdfPath = try await repository.exportPDF(doc.id)
            guard !pdfPath.isEmpty else {
                alert = AppAlert(title: "Export failed", message: "PDF was not generated")
                return
            }
            var updated = doc
            updated.pdfPath = pdfPath
            updated.status = .ready
            document = updated
        } catch {
            alert = AppAlert(title: "Export failed", message: error.localizedDescription)
        }
    }

    func getPDFURL() async -> URL? {
        guard let doc = document else { return nil }

        do {
            let url = try await repository.getPDFURL(by: doc.id, pdfPath: doc.pdfPath)
            if doc.pdfPath.isEmpty {
                document = try await repository.fetch(by: doc.id)
            }
            return url
        } catch {
            alert = AppAlert(title: "Export failed", message: error.localizedDescription)
            return nil
        }
    }
}
