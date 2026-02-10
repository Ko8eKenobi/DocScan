import SwiftUI

struct DocumentDetailsView: View {
    @StateObject private var vm: DocumentDetailsViewModel
    @State private var showDeleteConfirmation: Bool = false
    @State private var showRenameConfirmation: Bool = false
    @State private var newName: String = ""

    private(set) var id: UUID
    private let onDelete: () -> Void

    init(
        id: UUID,
        repository: IDocumentsRepository,
        onDelete: @escaping () -> Void
    ) {
        self.id = id
        self.onDelete = onDelete
        _vm = StateObject(
            wrappedValue: DocumentDetailsViewModel(id: id, repository: repository)
        )
    }

    var body: some View {
        Group {
            if let doc = vm.document {
                VStack {
                    Spacer()
                    Text(doc.title)
                        .font(.title)
                    Text("Created: \(doc.createdAt.formatted())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Status: \(doc.status.rawValue)")
                        .font(.subheadline)

                    if let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let fullPath = baseURL.appendingPathComponent(doc.previewPath).path

                        if let uiImage = UIImage(contentsOfFile: fullPath) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                        } else {
                            Image(systemName: doc.status.iconName)
                                .imageScale(.large)
                        }
                    }

                    Spacer()
                    HStack(spacing: 20) {
                        Button("Rename") { showRenameConfirmation = true }
                            .alert("Put new name", isPresented: $showRenameConfirmation) {
                                TextField("New name", text: $newName)
                                Button("Rename") {
                                    Task {
                                        await vm.rename(to: newName)
                                    }
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                        Button("Delete") { showDeleteConfirmation = true }
                            .alert("Delete document?", isPresented: $showDeleteConfirmation) {
                                Button("Delete") {
                                    onDelete()
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("This will permanently delete the document and its files.")
                            }
                    }
                    .padding(.horizontal)
                    Spacer()
                }
                .padding(.vertical)
            } else {
                // TODO: Empty doc
                ProgressView()
            }
        }
        .task { await vm.onAppear() }
        .navigationTitle("Document details view")
        .alert(item: $vm.alert) { $0.toAlert() }
    }
}
