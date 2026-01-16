//
//  ContentView.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/16/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading){
            TabView {
                Tab("Recieve", systemImage: "icloud.and.arrow.down.fill") {
                    RecieveView()
                }
                Tab("Send", systemImage: "paperplane") {
                    SendView()
                }
                Tab("Settings", systemImage: "gearshape.fill", role: .search) {
                    SettingsView()
                }
            }
        }
    }
}
    

#Preview {
    ContentView()
}
