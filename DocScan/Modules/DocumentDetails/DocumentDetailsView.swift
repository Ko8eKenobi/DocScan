import SwiftUI

enum ActiveSheet: Identifiable {
    case preview(URL)
    case share(URL)

    var id: String {
        switch self {
        case let .preview(url): "preview-\(url)"
        case let .share(url): "share-\(url)"
        }
    }
}

struct DocumentDetailsView: View {
    @StateObject private var vm: DocumentDetailsViewModel
    @State private var showDeleteConfirmation: Bool = false
    @State private var showRenameConfirmation: Bool = false
    @State private var newName: String = ""
    @State private var activeSheet: ActiveSheet?

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
                                .onTapGesture {
                                    Task {
                                        await openPDFPreview()
                                    }
                                }
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
                    .sheet(item: $activeSheet) { sheet in
                        switch sheet {
                        case let .preview(url):
                            PDFPreviewSheet(url: url)
                                .ignoresSafeArea()
                        case let .share(url):
                            ShareSheet(items: [url])
                                .ignoresSafeArea()
                        }
                    }
                    Spacer()
                }
                .padding(.vertical)
            } else {
                ProgressView()
            }
        }
        .task { await vm.onAppear() }
        .navigationTitle("Document details view")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await sharePDF() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
        }
        .alert(item: $vm.alert) { $0.toAlert() }
    }

    @MainActor
    private func openPDFPreview() async {
        if let url = await vm.getPDFURL() {
            activeSheet = .preview(url)
        }
    }

    @MainActor
    private func sharePDF() async {
        if let url = await vm.getPDFURL() {
            activeSheet = .share(url)
        }
    }
}
