import SwiftUI

@main
struct DocScanApp: App {
    let persistenceController = PersistenceController.shared
    let repository: DocumentsRepository
    @StateObject private var vm: DocumentsViewModel

    init() {
        let repository = DocumentsRepository(persistence: persistenceController)
        self.repository = repository
        _vm = StateObject(wrappedValue: DocumentsViewModel(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            DocumentsView(vm: vm)
        }
    }
}
