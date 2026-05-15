//
//  Item.swift
//  Antikaos
//
//  Created by Antônio Girardello Miguel on 15/05/26.
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
