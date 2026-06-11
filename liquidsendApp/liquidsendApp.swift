//
//  liquidsendApp.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/16/26.
//

import SwiftUI
import SwiftData

// MARK: - App entry

@main
struct liquidsendApp: App {
    @State private var coreStatus = CoreStatus() // Check core status through a observable
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coreStatus) // import to environment
        }
        .modelContainer(for: [SettingsModel.self, TransferHistoryEntry.self])
    }
}
