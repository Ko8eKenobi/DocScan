import SwiftUI

struct DocumentsView: View {
    @ObservedObject var vm: DocumentsViewModel
    
    var body: some View {
        NavigationStack {
            Group {
                if vm.documents.isEmpty {
                    VStack{
                        Text("No documents found.")
                            .font(.headline)
                        Image(systemName: "document.badge.plus")
                            .resizable()
                            .frame(width: 100, height: 100)
                    }
                    
                } else {
                    List {
                        ForEach(vm.documents) { doc in
                            DocumentRow(doc: doc)
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
                ToolbarItem {
                    Button{ addDocument() }
                    label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { refreshDocuments() }
            .onAppear { loadDocuments() }
        }
    }

    private func addDocument() {
        Task {
            await vm.addMockDocument()
        }
    }

    private func deleteDocument(at offsets: IndexSet) {
        Task {
            await vm.deleteDocument(at: offsets)
        }
    }
    
    private func refreshDocuments() {
        Task { await vm.refreshDocuments() }
    }
    
    private func loadDocuments() {
        Task { await vm.onAppear() }
    }
    private func deleteAllDocuments() {
        Task {
            await vm.deleteAll()
        }
    }
}
private struct DocumentRow: View {
    let doc: Document
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
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
    
    // TODO: Check after statuses implementation
    private var icon: String {
        switch doc.status {
        case .draft: "doc"
        case .ready: "checkmark.circle.fill"
        case .processing: "arrow.clockwise.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }
}

#Preview {
    PreviewHost()
}

private struct PreviewHost: View {
    let persistence = PersistenceController.preview
    @StateObject private var vm: DocumentsViewModel

    init() {
        let repo = DocumentsRepository(persistence: persistence)
        _vm = StateObject(wrappedValue: DocumentsViewModel(repository: repo))
    }

    var body: some View {
        DocumentsView(vm: vm)
            .environment(\.managedObjectContext, persistence.container.viewContext)
    }
}

