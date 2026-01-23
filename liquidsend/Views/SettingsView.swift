//
//  SettingsView.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/16/26.
//
import SwiftUI

// MARK: - Settings Variable here
// TODO: Make it swift data
enum deviceType: String, CaseIterable, Identifiable {
    case iphone
    case pc
    case browser
    case cli
    case server
    
    var id: Self { self }
    
    // Title for each case
    var title: String {
        switch self {
        case .iphone: return "iPhone"
        case .pc: return "PC"
        case .browser: return "Browser"
        case .cli: return "CLI"
        case .server: return "Server"
        }
    }
    
    // System image for each case
    var systemImage: String {
        switch self {
        case .iphone: return "iphone"
        case .pc: return "desktopcomputer"
        case .browser: return "globe"
        case .cli: return "terminal"
        case .server: return "server.rack"
        }
    }
}

// MARK: - body here
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var testvar1 = false
    @State private var testvar2 = false
    @State private var testvar3 = false
    @State private var testName = "Sponge Bob"
    @State private var isAdvancedNetworkingOn = false
    @State private var selectedDeviceIcon: deviceType = .iphone
    @State private var discoveryTimeout: Int = 500 // Default value
    let discoveryTimeoutOptions = [50,100,200,500,1000,5000]
    
    var body: some View {
        NavigationStack{
            Form {
                Section {
                    // Profile Stack
                    ZStack(alignment: .topLeading) {
                        // Avatar Image
                        Image("avatarFr")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90) // Because u already set scalledToFill, so only width here should be ok
                        VStack(alignment: .leading) {
                            // HStack for name
                            HStack {
                                TextField("Enter your name", text: $testName)
                                    .font(.system(size: 23, weight: .bold, design: .default))
                                    .underline(true, color: .gray)
                                Image(systemName: "pencil.line")
                                    .foregroundStyle(.secondary)
                                    .scaleEffect(1.5)
                                    .offset(y: 3)

                            }
                            // HStack for server status
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Server Operational_")
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                            // HStack for network status
                            HStack {
                                Image(systemName: "network")
                                Text("192.168.1.1@4570")
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                        }
                        .offset(x: 116, y: 5)
                    }
                }
                // Receive Section
                Section(header: Text("Receive")) {
                    Toggle("Quick Save", isOn: $testvar1)
                    Toggle("Quick Save for Favourites", isOn: $testvar2)
                    Toggle("Require PIN", isOn: $testvar3)
                    Toggle("Save media to gallery", isOn: $testvar1)
                    Toggle("Auto Finish", isOn: $testvar1)
                    Toggle("Save to history", isOn: $testvar1)
                }
                // Network Section
                Section(header: Text("Network")) {
                    // Advanced settings
                    Toggle("Advanced Networking", isOn: $isAdvancedNetworkingOn)
                    if isAdvancedNetworkingOn {
                        Toggle("Auto accepct share link requests", isOn: $testvar1)
                        // Device Icon Picker
                        Picker("Device Icon", selection: $selectedDeviceIcon) {
                            ForEach(deviceType.allCases) { device in
                                Label(device.title, systemImage: device.systemImage)
                                    .tag(device)
                            }
                        }
                        HStack {
                            Text("Device Model")
                            Spacer()
                            TextField("", text: $testName)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Port")
                            Spacer()
                            TextField("", text: $testName)
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
                            Picker("Timeout", selection: $discoveryTimeout) {
                                ForEach(discoveryTimeoutOptions, id: \.self) { value in
                                    Text("\(value) s")
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Toggle("Encryption", isOn: $testvar1)
                        
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
                        AboutAppViewView()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button ("close",systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inline)
            
        }
    }
}
#Preview {
    SettingsView()
}
