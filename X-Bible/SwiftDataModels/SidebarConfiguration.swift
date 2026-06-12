//
//  SidebarConfiguration.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/21/26.
//

import Foundation
import SwiftData

@Model
final class SidebarConfiguration {
    var pinnedCategories: [String]
    var createdAt: Date
    
    init(pinnedCategories: [String] = [], createdAt: Date = Date()) {
        self.pinnedCategories = pinnedCategories
        self.createdAt = createdAt
    }
}
