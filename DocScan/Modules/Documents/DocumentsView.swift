import SwiftUI

struct DocumentsView: View {
    @ObservedObject var vm: DocumentsViewModel
    @State private var showCamera = false
    @State private var capturedImage: UIImage?

    let onOpenDetails: (UUID) -> Void

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
                Button("Delete All") { deleteAllDocuments() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCamera = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable { refreshDocuments() }
        .onAppear { loadDocuments() }
        .alert(item: $vm.alert) { $0.toAlert() }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $capturedImage)
                .ignoresSafeArea()
        }
        .onChange(of: capturedImage) { image in
            guard let image else { return }
            createDocument(image)
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

    private func createDocument(_ image: UIImage) {
        Task {
            if let id = await vm.createDocument(from: image) {
                onOpenDetails(id)
            }
            capturedImage = nil
        }
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
    private let repo: DocumentsRepository
    init() {
        let repo = DocumentsRepository(persistence: persistence)
        self.repo = repo
        _vm = StateObject(wrappedValue: DocumentsViewModel(repository: repo))
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            DocumentsView(vm: vm) { id in router.push(.documentDetails(id: id)) }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case let .documentDetails(id):
                        DocumentDetailsView(id: id, repository: repo)
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
