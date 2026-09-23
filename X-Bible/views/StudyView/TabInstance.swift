//
//  TabInstance.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/23/26.
//

import Foundation
import XbibleEngine

// MARK: - Tab Model
struct TabInstance: Identifiable, Equatable {
    let id = UUID()
    var selectedModule: String
    var selectedBook: String
    var selectedChapter: Int
    var sections: [ModuleSection] = []
    
    // Split View Layout State per Tab
    var isSplitViewPresented = false
    var detailWidth: CGFloat = 350
    var selectedTab: StudyTab = .dictionary
    
    // Lookup States per Tab
    var selectedWordForLookup: String = ""
    var dictionaryResults: [XbibleEngine.DictionaryResult] = []
    var isDictionaryLoading = false
    
    var selectedStrongsForLookup: String = ""
    var selectedLexiconModule: String = ""
    var lexiconResults: [XbibleEngine.LexiconResult] = []
    var isLexiconLoading = false
    
    var selectedCommentaryModule: String = ""
    var commentaryResults: [XbibleEngine.Section] = []
    var isCommentaryLoading = false
    var currentCommentaryReference: String = ""
    
    static func == (lhs: TabInstance, rhs: TabInstance) -> Bool {
        lhs.id == rhs.id
    }
}
