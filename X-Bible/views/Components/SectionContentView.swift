//
//  SectionContentView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/23/26.
//

import SwiftUI
import XbibleEngine

struct SectionContentView: View {
    let sections: [XbibleEngine.Section]
    var onWordClick: ((XbibleEngine.Word) -> Void)? = nil
    
    // Default optimized text sizing constants
    private let titleFont: Font = .system(.title3, design: .serif, weight: .bold)
    private let verseTextFont: Font = .system(.body, design: .serif)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) { // Increased block spacing between sections
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: section.textDirection == .rtl ? .trailing : .leading, spacing: 14) {
                    
                    // --- 1. OPTIMIZED TITLE ROW ---
                    if !section.title.isEmpty {
                        FlowLayout(spacing: 5) {
                            ForEach(Array(section.title.enumerated()), id: \.offset) { _, item in
                                let commentaryTheme = WordView.Configuration(
                                    fontSize: 12,
                                )
                                WordView(word: item,config: commentaryTheme, onWordTextClicked: {
                                    onWordClick?(item)
                                })
                            }
                        }
                        .font(titleFont) // Cascades dynamic sizing to nested title strings
                        .padding(.bottom, 6)
                    }
                    
                    // --- 2. VERSE ROWS WITH BALANCED PACING ---
                    // Explicit block type binding context fixes key path and inference compiler issues
                    ForEach(section.verses, id: \.osisId) { (verse: XbibleEngine.Verse) in
                        HStack(alignment: .top, spacing: 8) {
                            FlowLayout(spacing: 6) {
                                ForEach(Array(verse.words.enumerated()), id: \.offset) { _, word in
                                    let commentaryTheme = WordView.Configuration(
                                        fontSize: 12,
                                    )
                                    
                                    WordView(word: word, config: commentaryTheme, onWordTextClicked: {
                                        onWordClick?(word)
                                    })
                                }
                            }
                            .font(verseTextFont) // Gracefully applies a clean serif reading experience
                        }
                        .padding(.vertical, 2) // Extra breathing room between long wrapped verses
                    }
                }
            }
        }
        .padding(.horizontal, 16) // Balanced horizontal margins on all devices
        .padding(.vertical, 20)   // Clean top/bottom scrolling safe zones
    }
}
