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
                    Image ("filzLogoV1")
                        .resizable()
                        .scaledToFill()
                        .frame(width:200)
                    Text("Filz!")
                        .font(.headline)
                }
                Spacer()
                Text("Filz is a open source project aims to provide a native LocalSend experience on iOS.")
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("You can find its source code at")
                        .foregroundStyle(.secondary)
                    Link("here...", destination: URL(string: "https://github.com/liuzifa1/Filz")!)
                }
                Text("© 2026 Zifa Liu. All rights reserved.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
        }
        .navigationTitle("Filz!")
    }
}

#Preview {
    AboutAppView()
}
