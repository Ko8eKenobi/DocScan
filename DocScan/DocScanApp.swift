//
//  DocScanApp.swift
//  DocScan
//
//  Created by Denis Shishmarev on 06.02.2026.
//

import SwiftUI

@main
struct DocScanApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
