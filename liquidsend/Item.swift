//
//  Item.swift
//  liquidsend
//
//  Created by liu zifa1 on 1/16/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
