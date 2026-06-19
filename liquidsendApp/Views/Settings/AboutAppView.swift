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
                    Text("Filz!")
                        .font(.headline)
                }
                Text("Filz is an app based on open-soured project Localsend, you can original localsend repository at")
                    .foregroundStyle(.secondary)
                Link("Here...", destination: URL(string: "https://localsend.org")!)
            }
        }
        .navigationTitle("Filz!")
    }
}
