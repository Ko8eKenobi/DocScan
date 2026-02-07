import OSLog

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "DocScan"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let repository = Logger(subsystem: subsystem, category: "repository")
}
