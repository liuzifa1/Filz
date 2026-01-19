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
    // These are the variables perpared for sendfilesview as .sheet
    @State private var showSendSheet = false
    @State private var tabSelection = 0
    @State private var perviousTabSelection = 0
    // This is prepared for opening settings view
    @State private var showSettingsPage = false
    
    // MARK: Body
    var body: some View {
        NavigationStack {
            TabView (selection: $tabSelection) {
                Tab("Home", systemImage: "house", value: 0) {
                    HomeView()
                }
                Tab("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90", value: 1) {
                    HistoryView()
                }
                Tab("SendFiles", systemImage: "paperplane", value: 2, role: .search) {
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button{
                        showSettingsPage = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            // This part detects if they need to show the sendfile sheet
            .onChange(of: tabSelection) { _, newValue in
                if newValue == 2 {
                    showSendSheet = true
                    // This switch the tab back to the pervious one with the variable collected in the else experssioin below
                    tabSelection = perviousTabSelection
                }
                else {
                    perviousTabSelection = newValue
                }
            }
            // This part detects if they need to show the settings page
            .navigationDestination(isPresented: $showSettingsPage) {
                SettingsView()
            }
            // .sheet here tells navistack that here's a function calling sheet view need him to process
            .sheet(isPresented: $showSendSheet) {
                SendView()
            }
            .navigationTitle("Sponge Bob")
        }
    }
}

// MARK: -


#Preview {
    ContentView()
}
