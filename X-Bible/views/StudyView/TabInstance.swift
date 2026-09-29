//
//  TabInstance.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/23/26.
//

import Foundation
import XbibleEngine

struct TabInstance: Identifiable, Equatable, Hashable {

    // MARK: - Identity

    let id: UUID

    // MARK: - Tab kind

    var type: TabType = .bible

    // MARK: - Bible / parallel / general book state

    var selectedModule: String = ""
    var selectedBook: String = ""
    var selectedChapter: Int = 1
    var sections: [ModuleSection] = []

    /// The id of the currently selected general-book leaf node.
    /// `nil` when nothing has been chosen yet.
    var selectedGeneralBookNodeId: UInt32? = nil

    // MARK: - Search state

    var searchQuery: String = ""
    var searchType: SearchType = .phrase
    var searchResults: [SearchHit] = []
    var searchHitsContent: [String: [ModuleSection]] = [:]
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

    // MARK: - Init

    init(id: UUID = UUID()) {
        self.id = id
    }

    // MARK: - Display

    var displayTitle: String {
        switch type {
        case .bible, .parallel, .generalBook:
            if selectedBook.isEmpty { return "Empty Tab" }
            return "\(selectedBook) \(selectedChapter)"
        case .search:
            if searchQuery.isEmpty { return "Search" }
            return "Search: \(searchQuery)"
        case .dictionary:
            return selectedWordForLookup.isEmpty ? "Dictionary" : selectedWordForLookup
        case .lexicon:
            return selectedStrongsForLookup.isEmpty ? "Lexicon" : selectedStrongsForLookup
        case .commentary:
            return currentCommentaryReference.isEmpty ? "Commentary" : currentCommentaryReference
        }
    }

    var displaySubtitle: String {
        switch type {
        case .bible, .parallel, .generalBook:
            return selectedModule.isEmpty ? "—" : selectedModule
        case .search:
            return selectedModule.isEmpty ? "Search" : selectedModule
        case .dictionary:
            return "Dictionary"
        case .lexicon:
            return selectedLexiconModule.isEmpty ? "Lexicon" : selectedLexiconModule
        case .commentary:
            return selectedCommentaryModule.isEmpty ? "Commentary" : selectedCommentaryModule
        }
    }

    // MARK: - Identity-based equality and hashing
    //
    // Treat each tab as a stable identity. Content changes should not
    // cause SwiftUI to consider the tab "different" — it should just
    // re-render the same cell. Everything below hinges on this.

    static func == (lhs: TabInstance, rhs: TabInstance) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
