//
//  StudyTab.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 6/20/26.
//

enum StudyTab: String, CaseIterable, Identifiable {
    case dictionary = "Dictionary"
    case lexicon = "Lexicon"
    case commentary = "Commentary"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .dictionary: return "character.book.closed"
        case .lexicon: return "abc"
        case .commentary: return "text.quote"
        }
    }
}
