//
//  SidebarItem.swift
//  XBible
//

import Foundation

enum SidebarItem: Hashable, CaseIterable, Equatable  {
    case study, store, all, bible, commentary, dictionary, glossary, lexicons, dailyDevotional, essays, generalBooks, unorthodox, bibleTimeline, audioBible, maps
    
    var title: String {
        switch self {
        case .study: return "Study"
        case .store: return "Store"
        case .all: return "All Library"
        case .bible: return "Biblical Texts"
        case .commentary: return "Commentaries"
        case .dictionary: return "Dictionaries"
        case .lexicons: return "Lexicons"
        case .glossary: return "Glossaries"
        case .dailyDevotional: return "Daily Devotionals"
        case .essays: return "Essays"
        case .generalBooks: return "Others"
        case .unorthodox: return "Cults"
        case .bibleTimeline: return "Timeline"
        case .audioBible: return "Audio Bible"
        case .maps: return "Maps"
        }
    }
    
    var icon: String {
        switch self {
        case .study: return "book"
        case .store: return "cart"
        case .all: return "books.vertical"
        case .bible: return "book.closed"
        case .commentary: return "text.quote"
        case .dictionary: return "character.book.closed"
        case .glossary: return "character.book.closed"
        case .lexicons: return "abc"
        case .dailyDevotional: return "sun.max"
        case .essays: return "text.justify.left"
        case .generalBooks: return "books.vertical"
        case .unorthodox: return "exclamationmark.triangle"
        case .bibleTimeline: return "calendar.day.timeline.left"
        case .audioBible: return "speaker.wave.2"
        case .maps: return "map"
        }
    }
}
