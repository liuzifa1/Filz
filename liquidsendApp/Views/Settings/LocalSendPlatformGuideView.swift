//
//  LocalSendPlatformGuideView.swift
//  liquidsend
//

import SwiftUI

struct LocalSendPlatformGuideView: View {
    private let downloadURL = URL(string: "https://localsend.org/download")!
    private let googlePlayURL = URL(
        string: "https://play.google.com/store/apps/details?id=org.localsend.localsend_app"
    )!
    private let wingetCommand = "winget install --id LocalSend.LocalSend --exact"
    private let chocolateyCommand = "choco install localsend"
    private let flatpakCommand = "flatpak install flathub org.localsend.localsend_app"
    private let snapCommand = "sudo snap install localsend"
    private let homebrewCommand = "brew install --cask localsend"

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    Image(systemName: "desktopcomputer.and.macbook")
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)

                    Text("Install LocalSend on another device, connect it to the same local network as Filz, and both devices will appear automatically.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)

                Text("Send a File")
                    .font(.headline)
                Label("Open LocalSend on the other device.", systemImage: "1.circle.fill")
                Label("In Filz, add files and choose that nearby device.", systemImage: "2.circle.fill")
                Label("Accept the transfer on the receiving device.", systemImage: "3.circle.fill")
            }

            Section("Windows") {
                Label("Windows 10 or later", systemImage: "desktopcomputer")
                commandInstallation("Install with WinGet", command: wingetCommand)
                commandInstallation("Install with Chocolatey", command: chocolateyCommand)
                Link(destination: downloadURL) {
                    Label("Download from the LocalSend Website", systemImage: "safari")
                }
            }

            Section("Linux") {
                commandInstallation("Install with Flatpak", command: flatpakCommand)
                commandInstallation("Install with Snap", command: snapCommand)
                Link(destination: downloadURL) {
                    Label("Choose a Website Download", systemImage: "safari")
                }
            }

            Section("macOS") {
                Label("macOS 11 Big Sur or later", systemImage: "macbook")
                commandInstallation("Install with Homebrew", command: homebrewCommand)
                Link(destination: downloadURL) {
                    Label("Download from the LocalSend Website", systemImage: "safari")
                }
            }

            Section("Android") {
                Label("Android 5.0 or later", systemImage: "smartphone")
                Link(destination: googlePlayURL) {
                    Label("Get It on Google Play", systemImage: "play.rectangle.fill")
                }
                Link(destination: downloadURL) {
                    Label("Download from the LocalSend Website", systemImage: "safari")
                }
            }
        }
        .navigationTitle("Use LocalSend on Other Platforms")
        .toolbarTitleDisplayMode(.inline)
    }

    private func commandInstallation(
        _ title: LocalizedStringKey,
        command: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: "terminal")
            }

            Text(command)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        LocalSendPlatformGuideView()
    }
}
