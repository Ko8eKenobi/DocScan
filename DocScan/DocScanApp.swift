import SwiftUI

@main
struct DocScanApp: App {
    let persistenceController = PersistenceController.shared
    let repository: DocumentsRepository
    @StateObject private var vm: DocumentsViewModel
    @StateObject private var router = Router()

    init() {
        let repository = DocumentsRepository(persistence: persistenceController)
        self.repository = repository
        _vm = StateObject(wrappedValue: DocumentsViewModel(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                DocumentsView(vm: vm) { router.push(.documentDetails(id: $0)) }
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case let .documentDetails(id: id):
                            DocumentDetailsView(id: id, repository: repository)
                        }
                    }
            }
        }
    }
}
