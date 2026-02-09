import SwiftUI

struct DocumentDetailsView: View {
    @StateObject private var vm: DocumentDetailsViewModel
    private(set) var id: UUID

    init(id: UUID, repository: DocumentsRepository) {
        self.id = id
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
                    Text("PDF: \(doc.pdfPath.isEmpty ? "Not available" : doc.pdfPath)")
                        .font(.subheadline)
                    Image(systemName: doc.status.iconName)
                        .imageScale(.large)
                    Spacer()
                    HStack(spacing: 20) {
                        Button("Rename") {}
                        Button("Delete") {}
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
