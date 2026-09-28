//
//  TabType.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/28/26.
//

import SwiftUI

/// The kind of content a tab hosts. Every `TabInstance` has exactly one.
///
/// Kept as a single enum (not a protocol hierarchy) because the set is
/// small, closed, and the UI needs to switch on it frequently — an enum
/// is cheaper and more ergonomic than existentials here.
enum TabType: String, Codable, CaseIterable, Identifiable {
    case bible
    case search
    case generalBook      // e.g. a Sword "GenBook" — commentary, devotional, etc.
    case dictionary
    case lexicon
    case commentary
    case parallel         // side-by-side Bible comparison

    var id: String { rawValue }

    // MARK: - Presentation

    /// SF Symbol for the tab's icon.
    var icon: String {
        switch self {
        case .bible:       return "book.closed.fill"
        case .search:      return "magnifyingglass"
        case .generalBook: return "book.pages"
        case .dictionary:  return "character.book.closed"
        case .lexicon:     return "abc"
        case .commentary:  return "text.quote"
        case .parallel:    return "rectangle.split.2x1"
        }
    }

    /// Accent tint for this tab kind. Used in the gallery, tab pill,
    /// and any type-specific chips.
    var tint: Color {
        switch self {
        case .bible:       return .accentColor
        case .search:      return .orange
        case .generalBook: return .purple
        case .dictionary:  return .teal
        case .lexicon:     return .indigo
        case .commentary:  return .brown
        case .parallel:    return .green
        }
    }

    /// Human-readable name shown in menus and the gallery.
    var displayName: String {
        switch self {
        case .bible:       return "Bible"
        case .search:      return "Search"
        case .generalBook: return "General Book"
        case .dictionary:  return "Dictionary"
        case .lexicon:     return "Lexicon"
        case .commentary:  return "Commentary"
        case .parallel:    return "Parallel"
        }
    }

    /// One-line description shown in the "New Tab" menu.
    var subtitle: String {
        switch self {
        case .bible:       return "Read scripture in a translation"
        case .search:      return "Full-text search across a module"
        case .generalBook: return "Open a book, devotional, or essay"
        case .dictionary:  return "Look up a word or phrase"
        case .lexicon:     return "Study a Strong's number"
        case .commentary:  return "Read commentary on a passage"
        case .parallel:    return "Compare two translations side by side"
        }
    }

    /// Whether this tab uses the standard reader pane (chapter nav,
    /// ScrollView of sections). Tabs that don't get a bespoke view.
    var usesReaderPane: Bool {
        switch self {
        case .bible, .parallel, .generalBook:
            return true
        case .search, .dictionary, .lexicon, .commentary:
            return false
        }
    }

    /// Whether a module picker makes sense for this tab kind.
    /// Search tabs need a target module; dictionary tabs don't.
    var requiresModule: Bool {
        switch self {
        case .bible, .search, .parallel, .generalBook, .commentary:
            return true
        case .dictionary, .lexicon:
            return false
        }
    }
}
