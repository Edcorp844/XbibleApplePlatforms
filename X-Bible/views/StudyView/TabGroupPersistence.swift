//
//  TabGroupPersistence.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/28/26.
//


//
//  TabGroup.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/28/26.
//

import SwiftUI

/// How a group survives across app launches.
enum TabGroupPersistence: String, Codable, CaseIterable, Identifiable {
    /// Never written to disk. Cleared on every cold launch.
    /// Use for scratch workspaces — a quick study session you don't
    /// want cluttering your saved groups.
    case temporary

    /// Written to disk and restored on launch.
    case persistent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .temporary:  return "Temporary"
        case .persistent: return "Persistent"
        }
    }

    var description: String {
        switch self {
        case .temporary:  return "Removed when the app is closed."
        case .persistent: return "Saved and restored across launches."
        }
    }

    var icon: String {
        switch self {
        case .temporary:  return "clock.arrow.circlepath"
        case .persistent: return "externaldrive.fill"
        }
    }
}

/// A named collection of tabs. Think of it as a workspace: a group of
/// related Bible tabs, search tabs, commentary tabs, etc., that the
/// user can switch between.
struct TabGroup: Identifiable, Equatable, Codable, Hashable {
    let id: UUID
    var name: String

    /// Whether this group survives app relaunch.
    var persistence: TabGroupPersistence

    /// Order of tabs *within this group*, by tab id. The `TabInstance`
    /// structs themselves live in `StudyViewModel.tabs`; a group holds
    /// only references to keep the array authoritative.
    var tabIds: [UUID]

    /// When the user last activated this group. Used for sorting and
    /// for restoring "the last group I was in" on relaunch.
    var lastActivatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        persistence: TabGroupPersistence = .persistent,
        tabIds: [UUID] = [],
        lastActivatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.persistence = persistence
        self.tabIds = tabIds
        self.lastActivatedAt = lastActivatedAt
    }

    var tabCount: Int { tabIds.count }
    var isEmpty: Bool { tabIds.isEmpty }
    var isTemporary: Bool { persistence == .temporary }
    var isPersistent: Bool { persistence == .persistent }

    static func == (lhs: TabGroup, rhs: TabGroup) -> Bool {
        lhs.id == rhs.id
    }
}
