import SwiftUI

struct DocumentsView: View {
    @ObservedObject var vm: DocumentsViewModel
    let onOpenDetails: (UUID) -> Void
    let onOpenCamera: () -> Void

    @State private var showDeleteAllConfirm = false

    var body: some View {
        VStack {
            if vm.documents.isEmpty {
                VStack {
                    Text("No documents found.")
                        .font(.headline)
                    Image(systemName: "document.badge.plus")
                        .resizable()
                        .frame(width: 100, height: 100)
                }
            } else {
                List {
                    ForEach(vm.documents) { doc in
                        Button {
                            onOpenDetails(doc.id)
                        } label: {
                            DocumentRow(doc: doc)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .task { await vm.loadMore(currentId: doc.id) }
                    }
                    .onDelete { deleteDocument(at: $0) }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Documents")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("Delete All") { showDeleteAllConfirm = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onOpenCamera()
                }
                label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable { refreshDocuments() }
        .onAppear { loadDocuments() }
        .alert(item: $vm.alert) { $0.toAlert() }
        .alert("Delete all files?", isPresented: $showDeleteAllConfirm) {
            Button("Remove all", role: .destructive) {
                deleteAllDocuments()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all documents. This action cannot be undone.")
        }
    }

    private func deleteDocument(at offsets: IndexSet) {
        Task { await vm.deleteDocument(at: offsets) }
    }

    private func refreshDocuments() {
        Task { await vm.refreshDocuments() }
    }

    private func loadDocuments() {
        Task { await vm.onAppear() }
    }

    private func deleteAllDocuments() {
        Task { await vm.deleteAll() }
    }
}

private struct DocumentRow: View {
    let doc: Document

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: doc.status.iconName)
                .imageScale(.large)
            VStack(alignment: .leading) {
                Text(doc.title)
                    .font(.title2)
                    .lineLimit(1)
                Text(doc.createdAt.formatted(date: .numeric, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Text(doc.status.rawValue)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PreviewHost()
}

private struct PreviewHost: View {
    let persistence = PersistenceController.preview
    @StateObject private var vm: DocumentsViewModel
    @StateObject private var router = Router()
    private let repository: DocumentsRepository
    init() {
        let storageService = StorageService()
        let repository = DocumentsRepository(
            persistence: persistence,
            storageService: storageService
        )
        self.repository = repository
        _vm = StateObject(wrappedValue: DocumentsViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            DocumentsView(
                vm: vm,
                onOpenDetails: { router.push(.documentDetails(id: $0)) },
                onOpenCamera: { router.present(.camera) }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case let .documentDetails(id):
                    DocumentDetailsView(
                        id: id,
                        repository: repository
                    ) {
                        Task {
                            await vm.deleteDocument(by: id)
                            router.pop()
                        }
                    }
                }
            }
        }
        .environment(\.managedObjectContext, persistence.container.viewContext)
        .task {
            await vm.onAppear()

            if let first = vm.documents.first {
                router.push(.documentDetails(id: first.id))
            }
        }
    }
}
