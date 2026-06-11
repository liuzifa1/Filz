//
//  SettingsView.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/16/26.
//
import SwiftUI
import SwiftData

// Main body for Settings view
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [SettingsModel]
    @Environment(\.dismiss) private var dismiss
    
    // Main body here, form view has been split from this view to imporove readability
    var body: some View {
        NavigationStack {
            if let settings = settingsList.first {
                SettingsFormView(settings: settings, dismiss: dismiss)
            } else {
                ProgressView()
                    .onAppear {
                        // Create default settings if none exist
                        let newSettings = SettingsModel()
                        modelContext.insert(newSettings)
                    }
            }
        }
    }
}

// Form View for Settings
struct SettingsFormView: View {
    @Environment(CoreStatus.self) private var coreStatus
    
    @Bindable var settings: SettingsModel // Import from SwiftData, and make it bindable
    var dismiss: DismissAction // Import dismiss function
    let discoveryTimeoutOptions = [50, 100, 200, 500, 1000, 5000] // Cause I'm using a picker thus the time out option is pre-given in here
    
    var body: some View {
        Form {
            Section {
            // Profile Stack
                HStack(alignment: .top) {
                    /// Avatar Image
                    Image("avatarFr")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90)
                    /// All the text
                    VStack(alignment: .leading) {
                        /// HStack for name
                        HStack {
                            TextField("Enter your name", text: $settings.userName)
                                .font(.system(size: 23, weight: .bold, design: .default))
                                .underline(true, color: .gray)
                            Image(systemName: "pencil.line")
                                .foregroundStyle(.secondary)
                                .scaleEffect(1.5)
                                .offset(x: -10, y: 3)
                        }
                        /// HStack for server status
                        HStack {
                            if coreStatus.isCoreRunning {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Server running")
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text("Server stopped")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        /// HStack for network status
                        HStack {
                            Image(systemName: "network")
                            Text(coreStatus.activePort.map { "Listening on port \($0)" } ?? "Not listening")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .offset(y: 5)
                }
            }
            // Receive Section
            Section(header: Text("Receive")) {
                Toggle("Quick Save", isOn: $settings.quickSave)
                Toggle("Quick Save for Favourites", isOn: $settings.quickSaveFavourites)
                Toggle("Require PIN", isOn: $settings.requirePIN)
                Toggle("Save media to gallery", isOn: $settings.saveMediaToGallery)
                Toggle("Auto Finish", isOn: $settings.autoFinish)
                Toggle("Save to history", isOn: $settings.saveToHistory)
            }
            // Network Section
            Section(header: Text("Network")) {
                // Advanced settings
                Toggle("Advanced Networking", isOn: $settings.isAdvancedNetworkingOn)
                if settings.isAdvancedNetworkingOn {
                    Toggle("Auto accepct share link requests", isOn: $settings.autoAcceptShareLink)
                    // Device Icon Picker
                    Picker("Device Icon", selection: $settings.selectedDeviceIcon) {
                        ForEach(AppDeviceIcon.allCases) { device in
                            Label(device.title, systemImage: device.systemImage)
                                .tag(device)
                        }
                    }
                    HStack {
                        Text("Device Model")
                        Spacer()
                        TextField("", text: $settings.deviceModel)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("", text: $settings.port)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .keyboardType(.numberPad)
                    }
                    NavigationLink("Interface B/W List") {
                        Text("Interface B/W List View")
                    }
                    // Discovery Timeout Picker
                    HStack {
                        Text("Discovery Timeout")
                        Spacer()
                        Picker("Timeout", selection: $settings.discoveryTimeout) {
                            ForEach(discoveryTimeoutOptions, id: \.self) { value in
                                Text("\(value) s")
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Toggle("Encryption", isOn: $settings.encryption)
                        .disabled(true)
                    
                }
                Button(
                    coreStatus.isCoreRunning ? "Restart Server" : "Start Server",
                    systemImage: coreStatus.isCoreRunning ? "arrow.clockwise" : "play.fill"
                ) {
                    if coreStatus.isCoreRunning {
                        restartServer()
                    } else {
                        startServer()
                    }
                }
                Button("Stop Server", systemImage: "stop.fill", role: .destructive) {
                    coreStatus.stop()
                }
                .disabled(!coreStatus.isCoreRunning)

                if let error = coreStatus.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            // About Section
            Section(header: Text("About")) {
                // App version HStack
                HStack {
                    Text("App")
                    Spacer()
                    Text("0.1_alpha")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Localsend Core")
                        Spacer()
                    Text(coreStatus.coreVersion)
                        .foregroundStyle(.secondary)
                }
                NavigationLink("About LocalSend") {
                    AboutAppView()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("close", systemImage: "xmark") {
                    dismiss()
                }
            }
        }
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
        .onAppear {
            coreStatus.refresh()
        }
    }

    private func startServer() {
        coreStatus.start(
            alias: settings.userName,
            portText: settings.port,
            deviceModel: settings.deviceModel,
            deviceIcon: settings.selectedDeviceIcon
        )
    }

    private func restartServer() {
        coreStatus.restart(
            alias: settings.userName,
            portText: settings.port,
            deviceModel: settings.deviceModel,
            deviceIcon: settings.selectedDeviceIcon
        )
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: SettingsModel.self, inMemory: true)
        .environment(CoreStatus())
}
