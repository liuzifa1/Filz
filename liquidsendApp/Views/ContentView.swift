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

// MARK: - The main content here
struct ContentView: View {
   // MARK: variables
   @Environment(\.modelContext) private var modelContext
   @Environment(\.scenePhase) private var scenePhase
   @Environment(CoreStatus.self) private var coreStatus
   @Query private var settings: [SettingsModel] // Fetch settings model from swiftdata
   
   @State private var showSettingsPage = false // Used for opening settings view
   @State private var showAttachmentPanel = false
   @State private var showDestinationPickerOnOpen = false
   @State private var showManualDestinationOnOpen = false
   @State private var attachmentAllowsMultipleDestinations = false
   @State private var selectedTab: MainTab = .send
   @State private var showReceiveDetails = false
   
   private var setting: SettingsModel {
           if let existing = settings.first{
               return existing
           } else {
               let new = SettingsModel()
               modelContext.insert(new)
               return new
           }
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
                  },
                  selectMultiple: {
                     coreStatus.clearDestinations()
                     presentAttachmentPanel(showDestinations: true, allowsMultipleDestinations: true)
                  },
                  sendToIP: {
                     coreStatus.clearDestinations()
                     presentAttachmentPanel(showManualDestination: true)
                  }
               )
                  .navigationTitle(setting.userName)
                  .toolbarTitleDisplayMode(.inlineLarge)
                  .toolbar {
                      // Attachments
                      ToolbarItem(placement: .topBarTrailing) {
                          Button {
                              coreStatus.clearDestinations()
                              presentAttachmentPanel()
                          } label: {
                              Image(systemName: "paperclip")
                          }
                          .accessibilityLabel("Attach items")
                      }
                      // Settings button
                      ToolbarItem(placement: .topBarTrailing) {
                          Button {
                              showSettingsPage = true
                          } label: {
                              Image(systemName: "gear")
                          }
                      }
                  }
                  // Sheet out settings page
                  .sheet(isPresented: $showSettingsPage) {
                     SettingsView()
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
      .onChange(of: scenePhase) { _, phase in
         guard phase == .active else { return }
         importSharedAttachments()
      }
      .task {
         importSharedAttachments()
         if setting.userName == "Sponge Bob" {
            setting.userName = SettingsModel.defaultDeviceName()
         }
         if !coreStatus.isCoreRunning {
            coreStatus.start(
               alias: setting.userName,
               portText: setting.port,
               deviceModel: setting.deviceModel,
               deviceIcon: setting.selectedDeviceIcon,
               receivePIN: setting.requirePIN ? setting.receivePIN : nil
            )
         }
         while !Task.isCancelled {
            if setting.userName == "Sponge Bob" {
               setting.userName = SettingsModel.defaultDeviceName()
            }
            coreStatus.refresh()
            coreStatus.applyReceivePolicy(
               quickSave: setting.quickSave,
               quickSaveFavourites: setting.quickSaveFavourites,
               favouriteDeviceTokens: Set(setting.favouriteDeviceTokens)
            )
            coreStatus.configureReceiveOptions(saveMediaToGallery: setting.saveMediaToGallery)
            SharedAttachmentInbox.exportFavouriteDevices(settings: setting, devices: coreStatus.nearbyDevices)
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

   private func importSharedAttachments() {
      let sharedImport = SharedAttachmentInbox.importPendingShare()
      guard !sharedImport.urls.isEmpty else { return }
      selectedTab = .send
      coreStatus.addFiles(sharedImport.urls)
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
         importSharedAttachments()
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
      .modelContainer(for: [SettingsModel.self, TransferHistoryEntry.self], inMemory: true)
      .environment(CoreStatus())
}
