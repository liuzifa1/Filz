//
//  SendView.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/19/26.
//

import SwiftUI

// MARK: -
struct SendView: View {
    @State private var shion
    // MARK: Body
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        Image ("logo512")
                            .resizable()
                            .scaledToFill()
                            .frame(width:100)
                        Text("Localsend")
                            .font(.headline)
                    }
                    Text("Localsend scands other client on your local network, then send files directly between two devices, No internet required.")
                        .foregroundStyle(.secondary)
                    Link("Learn More...", destination: URL(string: "https://localsend.org")!)
                }
                HStack(spacing: 8) {
                    Image(systemName: "nil")
                        .frame(width: 24, alignment: .center)
                    Toggle("Localsend Core", isOn: .constant(true))
                    //                Toggle("Quick Save", isOn: .constant(true))
                }
            }
            Section("Known Devices") {
                Button {
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "laptopcomputer")
                            .frame(width: 24, alignment: .center)
                        Text("Linux Desktop")
                    }
                    .foregroundStyle(.foreground)
                }
                
                Button {
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "iphone")
                            .frame(width: 24, alignment: .center)
                        Text("iPhone")
                    }
                    .foregroundStyle(.foreground)
                }
                
            }
            Section("Other Devices") {
                Button {
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "laptopcomputer")
                            .frame(width: 24, alignment: .center)
                        Text("Windows Desktop")
                    }
                    .foregroundStyle(.foreground)
                }
                
                Button {
                    
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "nil")
                            .frame(width: 24, alignment: .center)
                        Text("Other...")
                    }
                    .foregroundStyle(.foreground)
                }
            }
        }
    }
}

#Preview {
    SendView()
}
