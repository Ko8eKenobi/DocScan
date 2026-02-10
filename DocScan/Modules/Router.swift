import Foundation

enum Route: Hashable {
    case documentDetails(id: UUID)
}

enum Modal: Int, Identifiable {
    case camera
    case cameraPermissions

    var id: Int {
        rawValue
    }
}

@MainActor
final class Router: ObservableObject {
    @Published var path: [Route] = []
    @Published var modal: Modal?

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        _ = path.popLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    func present(_ modal: Modal) {
        self.modal = modal
    }

    func dismissModal() {
        modal = nil
    }
}
