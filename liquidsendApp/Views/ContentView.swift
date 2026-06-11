//
//  ContentView.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/16/26.
//

import SwiftUI
import SwiftData

// MARK: - The main content here
struct ContentView: View {
   // MARK: variables
   @Environment(\.modelContext) private var modelContext
   @Environment(\.scenePhase) private var scenePhase
   @Environment(CoreStatus.self) private var coreStatus
   @Query private var settings: [SettingsModel] // Fetch settings model from swiftdata
   
   @State private var showSettingsPage = false // Used for opening settings view
   @State private var showAttachmentPanel = false
   @State private var attachmentTarget: LocalSendDevice?
   
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
      TabView {
         // Tab for sending stuff
         Tab("Send", systemImage: "paperplane.fill") {
            NavigationStack {
               SendView { device in
                  attachmentTarget = device
                  showAttachmentPanel = true
               }
                  .navigationTitle(setting.userName)
                  .toolbarTitleDisplayMode(.inlineLarge)
                  .toolbar {
                      ToolbarItem(placement: .topBarTrailing) {
                          Button {
                              attachmentTarget = nil
                              showAttachmentPanel = true
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
                  .sheet(isPresented: $showAttachmentPanel) {
                     AttachmentSelectionSheet(target: attachmentTarget)
                  }
            }
         }
         // Tab for History
         Tab("History", systemImage: "clock.fill") {
            NavigationStack {
               HistoryView()
                  .navigationTitle("History")
                  .toolbarTitleDisplayMode(.inlineLarge)
            }
         }
      }
      .sheet(
         isPresented: Binding(
            get: { coreStatus.pendingReceiveRequest != nil },
            set: { _ in }
         )
      ) {
         if let request = coreStatus.pendingReceiveRequest {
            IncomingTransferSheet(request: request) { accepted in
               coreStatus.decideReceive(accepted: accepted)
            }
         }
      }
      .onOpenURL { url in
         guard url.scheme == SharedAttachmentInbox.urlScheme else { return }
         importSharedAttachments()
      }
      .onChange(of: scenePhase) { _, phase in
         guard phase == .active else { return }
         importSharedAttachments()
      }
      .task {
         importSharedAttachments()
         if !coreStatus.isCoreRunning {
            coreStatus.start(
               alias: setting.userName,
               portText: setting.port,
               deviceModel: setting.deviceModel,
               deviceIcon: setting.selectedDeviceIcon
            )
         }
         while !Task.isCancelled {
            coreStatus.refresh()
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
      let urls = SharedAttachmentInbox.importPendingFiles()
      guard !urls.isEmpty else { return }
      coreStatus.addFiles(urls)
      attachmentTarget = nil
      showAttachmentPanel = true
   }

}

#Preview {
   ContentView()
      .modelContainer(for: [SettingsModel.self, TransferHistoryEntry.self], inMemory: true)
      .environment(CoreStatus())
}
