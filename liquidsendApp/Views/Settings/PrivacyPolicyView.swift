//
//  PrivacyPolicyView.swift
//  liquidsend
//
//  Created by Codex on 7/8/26.
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section {
                Text("Filz! does not collect, sell, share, or track user data.")
                    .font(.headline)
                Text("The app has no analytics, advertising SDKs, or third-party tracking.")
                    .foregroundStyle(.secondary)
            }

            Section("Data Stored on This Device") {
                Text("Settings, favourite devices, transfer history, and draft shared files are stored locally on your device.")
                Text("Transfer history is optional and can be turned off or deleted from Settings.")
                Text("Files shared to Filz! are kept only as needed to prepare and send the transfer.")
            }

            Section("Transfers") {
                Text("Files and text are transferred directly between devices on your local network. Filz! does not upload your files to a cloud service or route them through a Filz! server.")
                Text("Nearby device names, addresses, and transfer metadata are used only to discover devices and complete transfers.")
            }

            Section("Permissions") {
                Text("Local Network access is used to discover and communicate with nearby LocalSend-compatible devices.")
                Text("Photo Library add access is used only when you choose to save received media to your gallery.")
                Text("File access is used only for files you select, receive, or share into the app.")
            }

            Section("Contact") {
                Text("If you have privacy questions, contact the app developer through the support channel where you received Filz!.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Last updated: July 8, 2026")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
