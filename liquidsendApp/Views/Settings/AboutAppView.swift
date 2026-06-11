//
//  AboutAppView.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/23/26.
//

import Foundation
import SwiftUI

struct AboutAppView: View {
    var body: some View {
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
                Text("LocalSend scans for other clients on your local network and transfers files directly without the internet.")
                    .foregroundStyle(.secondary)
                Link("Learn More...", destination: URL(string: "https://localsend.org")!)
            }
        }
    }
}
