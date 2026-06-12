//
//  PendingInstallation.swift
//  XBible
//

import Foundation
import SwiftData

@Model
final class PendingInstallation {
    @Attribute(.unique) var moduleName: String
    var source: String
    var status: String // "pending", "installing"
    var addedAt: Date
    
    init(moduleName: String, source: String, status: String = "pending", addedAt: Date = Date()) {
        self.moduleName = moduleName
        self.source = source
        self.status = status
        self.addedAt = addedAt
    }
}
