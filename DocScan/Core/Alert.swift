import SwiftUI

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
        AppLogger.app.error("Error: \(message)")
    }

    func toAlert() -> Alert {
        Alert(title: Text(title), message: Text(message))
    }
}
