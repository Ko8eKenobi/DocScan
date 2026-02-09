import Foundation

enum Route: Hashable {
    case documentDetails(id: UUID)
}

@MainActor
final class Router: ObservableObject {
    @Published var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        _ = path.popLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
