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
                    Text("What is Filz!")
                        .font(.headline)
                }
                Text("Filz aims to provide a native LocalSend experience on iOS. Thanks to the hard work of the LocalSend team, this app wouldn't be possible without the incredible foundation they laid.")
                    .foregroundStyle(.secondary)
                }
        }
        .navigationTitle("Filz!")
    }
}

#Preview {
    AboutAppView()
}
