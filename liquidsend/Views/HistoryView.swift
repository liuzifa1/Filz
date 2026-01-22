//
//  HistoryView.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/16/26.
//
import SwiftUI

struct HistoryView: View {
    var body: some View{
        List(1...20, id: \.self) { number in
            Text("\(number)")
        }
        .navigationTitle("History")
    }
        
}

#Preview {
    HistoryView()
}
