//
//  ContentView.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/16/26.
//

import SwiftUI
import SwiftData

// MARK: - File type enum
enum fileType: Int, CaseIterable, Hashable, Identifiable {
   case photo = 0
   case files = 1
   
   // Used for identifiable conformance
   var id: Int { rawValue }
   // Used for displaying title in picker
   var title: String {
      switch self {
      case .photo: return "Photo"
      case .files: return "Files"
      }
   }
}

// MARK: - The main content here
struct ContentView: View {
   // MARK: variables
   @Environment(\.modelContext) private var modelContext
   @Query private var settings: [SettingsModel] // Fetch settings model from swiftdata
   
   @State private var showSettingsPage = false // Used for opening settings view
   @State private var shouldMinimizeTabBar = false // Manuly control the tab bar visibility, just in case
   @State private var choosedFileType: fileType = .photo // initalize a varrible filetype for UI & sets its default into photo
   
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
               SendView()
                  .navigationTitle(setting.userName)
                  .toolbarTitleDisplayMode(.inlineLarge)
                  .toolbar {
                     // Choose button
                     ToolbarItem (placement: .topBarTrailing) {
                        Button {
                           
                        }
                        label: {
                           Text("選択")
                        }
                     }
                     // Avatar button
                     ToolbarItem (placement: .topBarTrailing) {
                        Button {
                           showSettingsPage = true
                        }
                        label: {
                           Image("avatarFr")
                              .resizable()
                              .scaledToFill()
                              .frame(width: 44, height: 44)
                              .clipShape(Circle())
                        }
                     }
                     .sharedBackgroundVisibility(.hidden)
                  }
                  // Sheet out settings page
                  .sheet(isPresented: $showSettingsPage) {
                     SettingsView()
                  }
            }
         }
         // Tab for History
         Tab("History", systemImage: "clock.fill") {
            NavigationStack {
               HistoryView()
                  .navigationTitle("History")
                  .toolbarTitleDisplayMode(.inlineLarge)
                  .toolbar {
                     ToolbarItem (placement: .topBarTrailing) {
                        Button {
                           
                        }
                        label: {
                           Image(systemName: "line.3.horizontal.decrease")
                        }
                     }
                  }
            }
         }
         // Tab for Search
         Tab("Search", systemImage: "magnifyingglass", role: .search) {
            NavigationStack {
               SearchView()
                  .navigationTitle("Search")
                  .toolbarTitleDisplayMode(.inlineLarge)
            }
         }
      }
   }
}

#Preview {
   ContentView()
      .modelContainer(for: SettingsModel.self, inMemory: true)
      .environment(CoreStatus())
}
