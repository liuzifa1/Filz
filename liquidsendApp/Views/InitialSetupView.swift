//
//  InitialSetupView.swift
//  liquidsend
//

import SwiftData
import SwiftUI
import UIKit

enum InitialSetupState {
    static let completionKey = "FilzDidCompleteInitialSetup"
    static let startedKey = "FilzDidStartInitialSetup"

    // This key shipped before onboarding. Its presence lets an updated install
    // bypass setup while a genuinely new install still sees it.
    static let existingInstallationKey = "FilzDidMigrateEncryptionDefault"
}

struct InitialSetupView: View {
    private enum Page: Int, CaseIterable {
        case welcome
        case localNetwork
        case photoLibrary
        case finished

        var number: Int { rawValue + 1 }
    }

    private enum LocalNetworkAccessState: Equatable {
        case idle
        case requesting
        case denied
        case unableToConfirm
    }

    @Environment(CoreStatus.self) private var coreStatus
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @Bindable var settings: SettingsModel
    let finishSetup: () -> Void
    let openPlatformGuide: () -> Void

    @State private var page = Page.welcome
    @State private var isRequestingPhotoAccess = false
    @State private var localNetworkAccessState = LocalNetworkAccessState.idle
    @State private var recheckLocalNetworkAccessWhenActive = false
    @State private var localNetworkPermissionProbe = LocalNetworkPermissionProbe()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    switch page {
                    case .welcome:
                        welcomePage
                    case .localNetwork:
                        localNetworkPage
                    case .photoLibrary:
                        photoLibraryPage
                    case .finished:
                        finishedPage
                    }
                }
                .id(page)
                .transition(.blurReplace)

                Spacer(minLength: 32)
                pageActions
            }
            .padding(.horizontal, 36)
            .padding(.top, 20)
            .padding(.bottom, 28)
            .navigationTitle("\(page.number)/\(Page.allCases.count)")
            .toolbarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
        .onChange(of: scenePhase) { _, phase in
            guard page == .localNetwork else { return }
            if phase != .active {
                if localNetworkAccessState == .requesting {
                    recheckLocalNetworkAccessWhenActive = true
                }
                return
            }
            guard recheckLocalNetworkAccessWhenActive else { return }
            recheckLocalNetworkAccessWhenActive = false
            localNetworkAccessState = .idle
            requestLocalNetworkAccess()
        }
        .onDisappear {
            localNetworkPermissionProbe.cancel()
        }
    }

    private var welcomePage: some View {
        SetupPageLayout(
            title: "Welcome to Filz!",
            message: "Let’s get Filz ready to send and receive files with nearby LocalSend devices."
        ) {
            Image(systemName: "paperplane.circle")
                .symbolEffect(.bounce.up.byLayer, options: .nonRepeating)
        }
    }

    private var localNetworkPage: some View {
        SetupPageLayout(
            title: localNetworkAccessState == .denied
                ? "Local Network Access Is Off"
                : "Find Nearby Devices",
            message: localNetworkMessage
        ) {
            if localNetworkAccessState == .denied {
                Image(systemName: "exclamationmark.triangle")
                    .symbolEffect(.bounce, options: .nonRepeating)
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .symbolEffect(.bounce, options: .nonRepeating)
            }
        }
    }

    private var localNetworkMessage: LocalizedStringKey {
        switch localNetworkAccessState {
        case .denied:
            "Without Local Network access, Filz can’t discover nearby LocalSend devices, send files, or receive files. Turn it on in Settings to continue setup."
        case .unableToConfirm:
            "Filz couldn’t confirm Local Network access. Check that your device is connected to a network, then try again."
        case .idle, .requesting:
            "Filz needs Local Network access to discover LocalSend devices on your Wi-Fi and transfer files directly between them. Your files never leave your local network."
        }
    }

    private var photoLibraryPage: some View {
        SetupPageLayout(
            title: "Save Received Media",
            message: "Allow add-only Photos access if you want Filz to save received photos and videos to your library. Filz can add new items but can’t read your existing library."
        ) {
            Image(systemName: "photo.on.rectangle.angled")
                .symbolEffect(.bounce, options: .nonRepeating)
        }
    }

    private var finishedPage: some View {
        SetupPageLayout(
            title: "You’re All Set",
            message: "Filz is ready to send files to and receive files from LocalSend on your other devices."
        ) {
            Image(systemName: "checkmark.circle")
                .symbolEffect(.bounce.up.byLayer, options: .nonRepeating)
        }
    }

    @ViewBuilder
    private var pageActions: some View {
        VStack(spacing: 12) {
            switch page {
            case .welcome:
                primaryButton("Continue") {
                    advance(to: .localNetwork)
                }

            case .localNetwork:
                if localNetworkAccessState == .denied {
                    primaryButton("Open Settings") {
                        openLocalNetworkSettings()
                    }

                    secondaryButton("Check Again") {
                        requestLocalNetworkAccess()
                    }
                } else {
                    primaryButton(
                        localNetworkAccessState == .requesting
                            ? LocalizedStringKey("Checking Access…")
                            : LocalizedStringKey("Allow Local Network Access")
                    ) {
                        requestLocalNetworkAccess()
                    }
                    .disabled(localNetworkAccessState == .requesting)
                }

            case .photoLibrary:
                primaryButton(
                    isRequestingPhotoAccess
                        ? LocalizedStringKey("Requesting Access…")
                        : LocalizedStringKey("Allow Photos Access")
                ) {
                    requestPhotoLibraryAccess()
                }
                .disabled(isRequestingPhotoAccess)

                secondaryButton("Skip for Now") {
                    MediaLibrarySaver.markFirstRunPhotoLibraryPromptHandled()
                    settings.saveMediaToGallery = false
                    try? modelContext.save()
                    advance(to: .finished)
                }

            case .finished:
                primaryButton("Finish Setup") {
                    finishSetup()
                }

                secondaryButton("Use LocalSend on Other Platforms") {
                    openPlatformGuide()
                }
            }
        }
    }

    private func primaryButton(
        _ title: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 30)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }

    private func secondaryButton(
        _ title: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(.primary)
    }

    private func advance(to nextPage: Page) {
        withAnimation(.smooth) {
            page = nextPage
        }
    }

    private func requestLocalNetworkAccess() {
        guard localNetworkAccessState != .requesting else { return }
        localNetworkAccessState = .requesting
        localNetworkPermissionProbe.request { result in
            switch result {
            case .allowed:
                recheckLocalNetworkAccessWhenActive = false
                startCoreAfterLocalNetworkAccess()
                advance(to: .photoLibrary)
            case .denied:
                Task { @MainActor in
                    // The first operation can report PolicyDenied before the
                    // system permission alert has received the user's choice.
                    try? await Task.sleep(for: .milliseconds(300))
                    guard page == .localNetwork else { return }
                    if scenePhase != .active {
                        recheckLocalNetworkAccessWhenActive = true
                    } else {
                        withAnimation(.smooth) {
                            localNetworkAccessState = .denied
                        }
                    }
                }
            case .unableToConfirm:
                withAnimation(.smooth) {
                    localNetworkAccessState = .unableToConfirm
                }
            }
        }
    }

    private func startCoreAfterLocalNetworkAccess() {
        if coreStatus.isCoreRunning {
            coreStatus.refreshDiscovery()
        } else {
            coreStatus.start(
                alias: settings.userName,
                portText: settings.port,
                deviceModel: settings.deviceModel,
                deviceIcon: settings.selectedDeviceIcon,
                useEncryption: settings.usesEncryption,
                receivePIN: settings.requirePIN ? settings.receivePIN : nil
            )
        }
    }

    private func openLocalNetworkSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        recheckLocalNetworkAccessWhenActive = true
        openURL(settingsURL)
    }

    private func requestPhotoLibraryAccess() {
        isRequestingPhotoAccess = true
        Task { @MainActor in
            let allowed = await MediaLibrarySaver.requestPhotoLibraryAddPermission(
                markFirstRunPromptHandled: true
            )
            settings.saveMediaToGallery = allowed
            try? modelContext.save()
            isRequestingPhotoAccess = false
            advance(to: .finished)
        }
    }
}

private struct SetupPageLayout<Symbol: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder let symbol: Symbol

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            symbol
                .font(.system(size: 104, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .padding(.bottom, 26)
                .accessibilityHidden(true)

            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.leading)

            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    InitialSetupView(settings: SettingsModel(), finishSetup: {}, openPlatformGuide: {})
        .modelContainer(for: SettingsModel.self, inMemory: true)
        .environment(CoreStatus())
}
