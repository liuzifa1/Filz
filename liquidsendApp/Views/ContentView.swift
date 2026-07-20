//
//  ContentView.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/16/26.
//

import SwiftUI
import SwiftData

private enum MainTab: Hashable {
   case send
   case history
}

private enum SettingsPresentation: String, Identifiable {
   case root
   case localSendPlatformGuide

   var id: String { rawValue }
}

// MARK: - The main content here
struct ContentView: View {
   // MARK: variables
   @Environment(\.modelContext) private var modelContext
   @Environment(\.scenePhase) private var scenePhase
   @Environment(CoreStatus.self) private var coreStatus
   @Environment(\.filzDebugModeEnabled) private var debugModeEnabled
   @Query private var settings: [SettingsModel] // Fetch settings model from swiftdata
   
   @State private var settingsPresentation: SettingsPresentation?
   @State private var showAttachmentPanel = false
   @State private var showDestinationPickerOnOpen = false
   @State private var showManualDestinationOnOpen = false
   @State private var attachmentAllowsMultipleDestinations = false
   @State private var selectedTab: MainTab = .send
   @State private var showReceiveDetails = false
   @State private var showInitialSetup = false
   @State private var showPlatformGuideAfterSetup = false
   @AppStorage(InitialSetupState.completionKey) private var didCompleteInitialSetup = false
   @AppStorage(FilzDebugSettings.replayWelcomeIntroKey) private var replayWelcomeIntro = false
   @AppStorage(FilzDebugSettings.alwaysShowWelcomeIntroKey) private var alwaysShowWelcomeIntro = false
   
   private var setting: SettingsModel {
           if let existing = settings.first {
               return existing
           }
           var descriptor = FetchDescriptor<SettingsModel>()
           descriptor.fetchLimit = 1
           if let existing = try? modelContext.fetch(descriptor).first {
               return existing
           }
           let new = SettingsModel()
           modelContext.insert(new)
           try? modelContext.save()
           return new
       }
   
   // MARK: Body
   var body: some View {
      TabView(selection: $selectedTab) {
         // Tab for sending stuff
         Tab("Send", systemImage: "paperplane.fill", value: MainTab.send) {
            NavigationStack {
               SendView(
                  selectDevice: { device in
                     coreStatus.selectDestination(device, replacingExisting: true)
                     presentAttachmentPanel()
                  }
               )
                  .navigationTitle(setting.userName)
                  .toolbarTitleDisplayMode(.inlineLarge)
                  .toolbar {
                      // More ways to send
                      ToolbarItem(placement: .topBarTrailing) {
                          Menu {
                              Button {
                                  coreStatus.clearDestinations()
                                  presentAttachmentPanel()
                              } label: {
                                  Label("Add Attachments", systemImage: "paperclip")
                              }
                              Button {
                                  coreStatus.clearDestinations()
                                  presentAttachmentPanel(showManualDestination: true)
                              } label: {
                                  Label("Send to IP Address", systemImage: "network")
                              }
                              Button {
                                  coreStatus.clearDestinations()
                                  presentAttachmentPanel(showDestinations: true, allowsMultipleDestinations: true)
                              } label: {
                                  Label("Choose Multiple Destinations", systemImage: "person.2.badge.plus")
                              }
                          } label: {
                              Image(systemName: "plus")
                          }
                          .accessibilityLabel("More ways to send")
                      }
                      // Settings button
                      ToolbarItem(placement: .topBarTrailing) {
                          Button {
                              settingsPresentation = .root
                          } label: {
                              Image(systemName: "gear")
                          }
                      }
                  }
                  .sheet(isPresented: $showAttachmentPanel, onDismiss: resetAttachmentPresentation) {
                     AttachmentSelectionSheet(
                        showDestinationPickerOnAppear: showDestinationPickerOnOpen,
                        showManualDestinationOnAppear: showManualDestinationOnOpen,
                        allowsMultipleDestinations: attachmentAllowsMultipleDestinations
                     )
                  }
            }
         }
         // Tab for History
         Tab("History", systemImage: "clock.fill", value: MainTab.history) {
            NavigationStack {
               HistoryView()
                  .navigationTitle("History")
                  .toolbarTitleDisplayMode(.inlineLarge)
            }
         }
      }
      .onOpenURL { url in
         handleDeepLink(url)
      }
      .sheet(isPresented: $showReceiveDetails) {
         if let request = coreStatus.pendingReceiveRequest {
            IncomingTransferSheet(request: request) { accepted in
               coreStatus.decideReceive(accepted: accepted)
               showReceiveDetails = false
            }
         }
      }
      .sheet(item: $settingsPresentation, onDismiss: handleSettingsDismissal) { presentation in
         SettingsView(
            showPlatformGuideOnAppear: presentation == .localSendPlatformGuide
         )
         .id(presentation.id)
      }
      .sheet(isPresented: $showInitialSetup, onDismiss: presentPlatformGuideAfterSetupIfNeeded) {
         InitialSetupView(
            settings: setting,
            finishSetup: completeInitialSetup,
            openPlatformGuide: {
               showPlatformGuideAfterSetup = true
               completeInitialSetup()
            }
         )
      }
      .onChange(of: scenePhase) { _, phase in
         guard phase == .active else { return }
         Task { await importSharedAttachments() }
      }
      .task {
         configureInitialSetupPresentation()
         await importSharedAttachments()
         if setting.userName == "Sponge Bob" {
            setting.userName = SettingsModel.defaultDeviceName()
            try? modelContext.save()
         }
         migrateEncryptionDefaultIfNeeded()
         startCoreIfNeeded()
         while !Task.isCancelled {
            if setting.userName == "Sponge Bob" {
               setting.userName = SettingsModel.defaultDeviceName()
               try? modelContext.save()
            }
            coreStatus.refresh()
            coreStatus.applyReceivePolicy(
               quickSave: setting.quickSave,
               quickSaveFavourites: setting.quickSaveFavourites,
               favouriteDeviceTokens: Set(setting.favouriteDeviceTokens)
            )
            coreStatus.configureReceiveOptions(saveMediaToGallery: setting.saveMediaToGallery)
            SharedAttachmentInbox.exportFavouriteDevices(settings: setting, devices: coreStatus.nearbyDevices)
            FavouriteStore.syncSnapshots(
               devices: coreStatus.nearbyDevices,
               favouriteTokens: Set(setting.favouriteDeviceTokens),
               networkKey: coreStatus.currentNetworkKey,
               context: modelContext
            )
            let drafts = coreStatus.drainHistoryDrafts()
            if setting.saveToHistory {
               drafts.forEach { modelContext.insert(TransferHistoryEntry(draft: $0)) }
               if !drafts.isEmpty {
                  try? modelContext.save()
               }
            }
            try? await Task.sleep(for: .seconds(1))
         }
      }
   }

   private func completeInitialSetup() {
      didCompleteInitialSetup = true
      showInitialSetup = false
      startCoreIfNeeded()
   }

   private func presentPlatformGuideAfterSetupIfNeeded() {
      guard showPlatformGuideAfterSetup else { return }
      showPlatformGuideAfterSetup = false
      settingsPresentation = .localSendPlatformGuide
   }

   private func handleSettingsDismissal() {
      guard debugModeEnabled, replayWelcomeIntro else { return }
      beginDebugWelcomeReplay()
   }

   private func beginDebugWelcomeReplay() {
      replayWelcomeIntro = false
      didCompleteInitialSetup = false
      UserDefaults.standard.set(true, forKey: InitialSetupState.startedKey)
      showInitialSetup = true
   }

   private func configureInitialSetupPresentation() {
      if debugModeEnabled, replayWelcomeIntro || alwaysShowWelcomeIntro {
         beginDebugWelcomeReplay()
         return
      }

      let defaults = UserDefaults.standard
      if defaults.object(forKey: InitialSetupState.completionKey) == nil,
         !defaults.bool(forKey: InitialSetupState.startedKey) {
         if defaults.object(forKey: InitialSetupState.existingInstallationKey) != nil {
            didCompleteInitialSetup = true
         } else {
            // Keep an interrupted first-run setup resumable even after the
            // legacy migration key is written later in this launch.
            defaults.set(true, forKey: InitialSetupState.startedKey)
         }
      }
      showInitialSetup = !didCompleteInitialSetup
   }

   private func startCoreIfNeeded() {
      guard didCompleteInitialSetup, !coreStatus.isCoreRunning else { return }
      coreStatus.start(
         alias: setting.userName,
         portText: setting.port,
         deviceModel: setting.deviceModel,
         deviceIcon: setting.selectedDeviceIcon,
         useEncryption: setting.usesEncryption,
         receivePIN: setting.requirePIN ? setting.receivePIN : nil
      )
   }

   private func migrateEncryptionDefaultIfNeeded() {
      let key = "FilzDidMigrateEncryptionDefault"
      guard !UserDefaults.standard.bool(forKey: key) else { return }
      setting.encryption = true
      try? modelContext.save()
      UserDefaults.standard.set(true, forKey: key)
   }

   private func importSharedAttachments(waitingUpTo timeout: TimeInterval = 0) async {
      // The share extension opens the app before it finishes materializing
      // the items; when launched through its deep link, wait for the manifest
      // to land instead of importing nothing.
      if timeout > 0 {
         let deadline = Date().addingTimeInterval(timeout)
         while !SharedAttachmentInbox.hasPendingShare, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(250))
         }
      }
      // Off the main thread: bookmark handoffs from the share extension are
      // copied here, which can be slow for large files.
      let sharedImport = await Task.detached(priority: .userInitiated) {
         SharedAttachmentInbox.importPendingShare()
      }.value
      guard !sharedImport.urls.isEmpty else { return }
      selectedTab = .send
      let textURLs = Set(sharedImport.textPreviews.keys)
      let fileURLs = sharedImport.urls.filter { !textURLs.contains($0) }
      if fileURLs.isEmpty,
         sharedImport.textPreviews.count == 1,
         let textItem = sharedImport.textPreviews.first {
         coreStatus.selectTextMessage(textItem.key, preview: textItem.value)
      } else {
         if !fileURLs.isEmpty {
            coreStatus.addFiles(fileURLs)
         }
         for url in sharedImport.urls {
            if let preview = sharedImport.textPreviews[url] {
               coreStatus.addTextFile(url, preview: preview)
            }
         }
      }
      coreStatus.clearDestinations()
      if !sharedImport.selectedFavouriteIDs.isEmpty {
         for device in coreStatus.nearbyDevices
         where sharedImport.selectedFavouriteIDs.contains(device.id)
            || sharedImport.selectedFavouriteIDs.contains(device.token) {
            coreStatus.selectDestination(device)
         }
      }
      presentAttachmentPanel(
         showDestinations: sharedImport.openDestinationPicker || coreStatus.selectedDevices.isEmpty,
         allowsMultipleDestinations: true
      )
   }

   private func handleDeepLink(_ url: URL) {
      guard url.scheme == SharedAttachmentInbox.urlScheme else { return }
      if url.host == "shared-inbox" {
         Task { await importSharedAttachments(waitingUpTo: 30) }
         return
      }
      if url.host == "receive" || url.host == "transfer" {
         coreStatus.refresh()
         selectedTab = .send
         showReceiveDetails = coreStatus.pendingReceiveRequest != nil
      }
   }

   private func presentAttachmentPanel(
      showDestinations: Bool = false,
      showManualDestination: Bool = false,
      allowsMultipleDestinations: Bool = false
   ) {
      showDestinationPickerOnOpen = showDestinations
      showManualDestinationOnOpen = showManualDestination
      attachmentAllowsMultipleDestinations = allowsMultipleDestinations
      showAttachmentPanel = true
   }

   private func resetAttachmentPresentation() {
      if !coreStatus.isSending {
         coreStatus.clearDestinations()
      }
      showDestinationPickerOnOpen = false
      showManualDestinationOnOpen = false
      attachmentAllowsMultipleDestinations = false
   }

}

#Preview {
   ContentView()
      .modelContainer(for: [SettingsModel.self, TransferHistoryEntry.self, FavouriteDevice.self], inMemory: true)
      .environment(CoreStatus())
}
