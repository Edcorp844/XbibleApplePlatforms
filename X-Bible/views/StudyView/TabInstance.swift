//
//  TabInstance.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/23/26.
//

import Foundation
import XbibleEngine

struct TabInstance: Identifiable, Equatable {
    let id = UUID()

    // MARK: - Tab identity
    var type: TabType = .bible

    // MARK: - Bible state
    var selectedModule: String = ""
    var selectedBook: String = ""
    var selectedChapter: Int = 1
    var sections: [ModuleSection] = []

    // MARK: - Search state
    var searchQuery: String = ""
    var searchType: SearchType = .phrase
    var searchResults: [SearchHit] = []
    var searchHitsContent: [String: [ModuleSection]] = [:]   // key = reference
    var isSearching: Bool = false
    var searchLoadProgress: Double = 0

    // MARK: - Split view layout
    var isSplitViewPresented = false
    var detailWidth: CGFloat = 350
    var selectedTab: StudyTab = .dictionary

    // MARK: - Dictionary lookup
    var selectedWordForLookup: String = ""
    var dictionaryResults: [XbibleEngine.DictionaryResult] = []
    var isDictionaryLoading = false

    // MARK: - Lexicon lookup
    var selectedStrongsForLookup: String = ""
    var selectedLexiconModule: String = ""
    var lexiconResults: [XbibleEngine.LexiconResult] = []
    var isLexiconLoading = false

    // MARK: - Commentary
    var selectedCommentaryModule: String = ""
    var commentaryResults: [XbibleEngine.Section] = []
    var isCommentaryLoading = false
    var currentCommentaryReference: String = ""

    // MARK: - Convenience
    /// A human-readable title for tab pickers.
    var displayTitle: String {
        switch type {
        case .bible:
            if selectedBook.isEmpty { return "Empty Tab" }
            return "\(selectedBook) \(selectedChapter)"
        case .search:
            if searchQuery.isEmpty { return "Search" }
            return "Search: \(searchQuery)"
        default:
            // TODO: implement per-type titles
            return type.displayName
        }
    }

    var displaySubtitle: String {
        switch type {
        case .bible:
            return selectedModule.isEmpty ? "—" : selectedModule
        case .search:
            return "Search"//searchType.displayName
        default:
            return type.displayName
        }
    }
    static func == (lhs: TabInstance, rhs: TabInstance) -> Bool {
        lhs.id == rhs.id
    }
}
