//
//  StudyViewUtils.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/23/26.
//

import Foundation

#if os(macOS)
import AppKit
#endif

// MARK: - Notifications & Helpers

extension Notification.Name {
    static let requestTabDuplication = Notification.Name("requestTabDuplication")
}

struct StudyTabPayload {
    let module: String
    let book: String
    let chapter: Int
}
