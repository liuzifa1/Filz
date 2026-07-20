//
//  liquidsendApp.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/16/26.
//

import SwiftUI
import SwiftData

enum FilzDebugSettings {
    static let replayWelcomeIntroKey = "FilzDebugReplayWelcomeIntro"
    static let alwaysShowWelcomeIntroKey = "FilzDebugAlwaysShowWelcomeIntro"
    static let showNetworkDiagnosticsKey = "FilzDebugShowNetworkDiagnostics"
}

private struct FilzDebugModeEnabledKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var filzDebugModeEnabled: Bool {
        get { self[FilzDebugModeEnabledKey.self] }
        set { self[FilzDebugModeEnabledKey.self] = newValue }
    }
}

// MARK: - App entry

@main
struct liquidsendApp: App {
    @State private var coreStatus = CoreStatus() // Check core status through a observable

    // Enable this locally to expose developer controls in Settings.
    private let debugModeEnabled = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coreStatus) // import to environment
                .environment(\.filzDebugModeEnabled, debugModeEnabled)
        }
        .modelContainer(for: [SettingsModel.self, TransferHistoryEntry.self, FavouriteDevice.self])
    }
}
