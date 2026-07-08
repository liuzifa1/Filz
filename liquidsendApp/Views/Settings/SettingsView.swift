//
//  SettingsView.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/16/26.
//
import SwiftUI
import SwiftData
import UIKit

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
                        ensureSettingsModelExists()
                    }
            }
        }
    }

    private func ensureSettingsModelExists() {
        var descriptor = FetchDescriptor<SettingsModel>()
        descriptor.fetchLimit = 1
        if (try? modelContext.fetch(descriptor).first) != nil {
            return
        }
        modelContext.insert(SettingsModel())
        try? modelContext.save()
    }
}

// Form View for Settings
struct SettingsFormView: View {
    @Environment(CoreStatus.self) private var coreStatus
    @Environment(\.modelContext) private var modelContext
    @Query private var historyEntries: [TransferHistoryEntry]
    @State private var identityName = ""
    @State private var showIdentityEditor = false
    @State private var showHistoryDeleteConfirmation = false
    
    @Bindable var settings: SettingsModel // Import from SwiftData, and make it bindable
    var dismiss: DismissAction // Import dismiss function
    let discoveryTimeoutOptions = [50, 100, 200, 500, 1000, 5000] // Cause I'm using a picker thus the time out option is pre-given in here
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Device Name", value: settings.userName)
                Button("Change Device Name", systemImage: "person.crop.circle.badge.pencil") {
                    identityName = settings.userName
                    showIdentityEditor = true
                }
            } header: {
                Text("Identity")
            }
            // Receive Section
            Section(header: Text("Receive")) {
                Toggle("Quick Save", isOn: $settings.quickSave)
                Toggle("Quick Save for Favourites", isOn: $settings.quickSaveFavourites)
                Toggle("Require PIN", isOn: $settings.requirePIN)
                if settings.requirePIN {
                    TextField("Receive PIN", text: $settings.receivePIN)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                }
                Toggle("Save media to gallery", isOn: $settings.saveMediaToGallery)
                Toggle("Auto Finish", isOn: $settings.autoFinish)
                Toggle("Save to history", isOn: $settings.saveToHistory)
                Button("Delete History", systemImage: "trash", role: .destructive) {
                    showHistoryDeleteConfirmation = true
                }
                .disabled(historyEntries.isEmpty)
            }
            Section {
                NavigationLink {
                    FavouriteDevicesView(settings: settings, devices: coreStatus.nearbyDevices)
                } label: {
                    LabeledContent("Saved Devices", value: "\(settings.favouriteDeviceTokens.count)")
                }
            } header: {
                Text("Favourites")
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
                .contentShape(Rectangle())
                .onTapGesture(count: 3, perform: toggleAppIcon)
                HStack {
                    Text("Localsend Core")
                        Spacer()
                    Text(coreStatus.coreVersion)
                        .foregroundStyle(.secondary)
                }
                NavigationLink("About Filz!") {
                    AboutAppView()
                }
                NavigationLink("Open Source Acknowledgements") {
                    OpenSourceAcknowledgementsView()
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
            identityName = settings.userName
            coreStatus.refresh()
            if settings.requirePIN && settings.receivePIN.isEmpty {
                settings.receivePIN = String(Int.random(in: 100_000...999_999))
            }
            applyReceivePIN()
        }
        .onChange(of: settings.requirePIN) { _, enabled in
            if enabled && settings.receivePIN.isEmpty {
                settings.receivePIN = String(Int.random(in: 100_000...999_999))
            }
            applyReceivePIN()
        }
        .onChange(of: settings.isAdvancedNetworkingOn) { _, _ in
            restartServerIfRunning()
        }
        .onChange(of: settings.encryption) { _, _ in
            restartServerIfRunning()
        }
        .onChange(of: settings.receivePIN) { _, _ in applyReceivePIN() }
        .alert("Change Device Name", isPresented: $showIdentityEditor) {
            TextField("Device Name", text: $identityName)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) {}
            Button("Apply", action: applyIdentity)
                .disabled(identityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text(coreStatus.isCoreRunning ? "Applying this restarts the LocalSend server so nearby devices see the new name." : "This name is advertised to nearby LocalSend devices when the server starts.")
        }
        .alert("Delete all transfer history?", isPresented: $showHistoryDeleteConfirmation) {
            Button("Delete History", role: .destructive) {
                historyEntries.forEach(modelContext.delete)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all saved transfer records.")
        }
    }

    private func startServer() {
        coreStatus.start(
            alias: settings.userName,
            portText: settings.port,
            deviceModel: settings.deviceModel,
            deviceIcon: settings.selectedDeviceIcon,
            useEncryption: settings.usesEncryption,
            receivePIN: settings.requirePIN ? settings.receivePIN : nil
        )
    }

    private func applyIdentity() {
        let normalizedName = identityName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return }
        identityName = normalizedName
        settings.userName = normalizedName
        if coreStatus.isCoreRunning {
            restartServer()
        } else {
            startServer()
        }
        showIdentityEditor = false
    }

    private func restartServer() {
        coreStatus.restart(
            alias: settings.userName,
            portText: settings.port,
            deviceModel: settings.deviceModel,
            deviceIcon: settings.selectedDeviceIcon,
            useEncryption: settings.usesEncryption,
            receivePIN: settings.requirePIN ? settings.receivePIN : nil
        )
    }

    private func restartServerIfRunning() {
        guard coreStatus.isCoreRunning else { return }
        restartServer()
    }

    private func applyReceivePIN() {
        coreStatus.configureReceivePIN(settings.requirePIN ? settings.receivePIN : nil)
    }

    private func toggleAppIcon() {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let nextIcon = UIApplication.shared.alternateIconName == "catz" ? nil : "catz"
        UIApplication.shared.setAlternateIconName(nextIcon)
    }
}
private struct FavouriteDevicesView: View {
    @Bindable var settings: SettingsModel
    let devices: [LocalSendDevice]

    var body: some View {
        List {
            if settings.favouriteDeviceTokens.isEmpty {
                ContentUnavailableView("No Favourites", systemImage: "star")
            } else {
                ForEach(settings.favouriteDeviceTokens, id: \.self) { fingerprint in
                    let device = devices.first { $0.id == fingerprint || $0.token == fingerprint }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(device?.alias ?? "Saved Device", systemImage: device?.systemImage ?? "desktopcomputer")
                            Spacer()
                            if let protocolName = device?.protocol {
                                Text(protocolName.uppercased())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let device {
                            Text(device.endpoint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(fingerprint)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .swipeActions {
                        Button("Remove", systemImage: "star.slash", role: .destructive) {
                            settings.favouriteDeviceTokens.removeAll { $0 == fingerprint }
                        }
                    }
                }

                Section {
                    Button("Clear Favourites", systemImage: "star.slash", role: .destructive) {
                        settings.favouriteDeviceTokens.removeAll()
                    }
                }
            }
        }
        .navigationTitle("Favourites")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: SettingsModel.self, inMemory: true)
        .environment(CoreStatus())
}
