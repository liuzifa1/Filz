//
//  SearchView.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/16/26.
//
import SwiftUI

struct SearchView: View {
    @State private var searchText: String = ""
    
    var body: some View {
        VStack{
            Text("SearchView")
        }
        .searchable(text: $searchText)
    }
}


#Preview {
    SearchView()
}
