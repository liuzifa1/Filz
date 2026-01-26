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
    @State var coreStatus = CoreStatus()
    
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
//                            Image(systemName: "checkmark.circle.fill")
//                                .foregroundStyle(.green)
//                            Text("Server Operational_")
//                                .foregroundStyle(.secondary)
//                                .italic()
//                        }
                            if coreStatus.isCoreRunning {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Server Operational_")
                                    .foregroundStyle(.secondary)
                                    .italic()
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text("Server Down_")
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                        }
                        /// HStack for network status
                        HStack {
                            Image(systemName: "network")
                            Text("192.168.1.1@4570")
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    }
                    .offset(y: 5)
                }
            }
            // Developer Area
            Section(header: Text("TestFlights")) {
                Toggle("Toggle Sever Status", isOn: $coreStatus.isCoreRunning)
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
                        ForEach(DeviceType.allCases) { device in
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
                    
                }
                Button("Restart Server") {
                    
                }
                Button("Stop Server") {
                    
                }
                .foregroundStyle(.red)
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
                    Text("0.1.0")
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
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: SettingsModel.self, inMemory: true)
        .environment(CoreStatus())
}
