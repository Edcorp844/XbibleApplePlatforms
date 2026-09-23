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
    
    @EnvironmentObject private var textConfigVM: TextConfigViewModel
    
    var body: some View {
        let config = textConfigVM.config
        
        // Dynamically compute layout spacers from global configuration line spacing
        let lineSpacingFactor = CGFloat(config.lineSpacing)
        let sectionSpacing = 24.0 * lineSpacingFactor
        let titleBottomPadding = 6.0 * lineSpacingFactor
        let verseVerticalPadding = 2.0 * lineSpacingFactor
        let verseBlockSpacing = 14.0 * lineSpacingFactor
        
        VStack(alignment: .leading, spacing: sectionSpacing) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: section.textDirection == .rtl ? .trailing : .leading, spacing: verseBlockSpacing) {
                    
                    // --- 1. OPTIMIZED TITLE ROW ---
                    if !section.title.isEmpty {
                        FlowLayout(spacing: CGFloat(config.wordSpacing)) {
                            ForEach(Array(section.title.enumerated()), id: \.offset) { _, item in
                                WordView(word: item, isTitle: true, onWordTextClicked: {
                                    onWordClick?(item)
                                })
                            }
                        }
                        .padding(.bottom, titleBottomPadding)
                    }
                    
                    // --- 2. VERSE ROWS WITH DYNAMIC LINE AND WORD SPACING ---
                    ForEach(section.verses, id: \.osisId) { (verse: XbibleEngine.Verse) in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(verse.number)")
                                .font(.system(size: CGFloat(config.fontSize) * 0.8, weight: .regular))
                                .foregroundColor(.secondary)
                                .padding(.trailing, 4)
                                .baselineOffset(4)
                            
                            FlowLayout(spacing: CGFloat(config.wordSpacing)) {
                                ForEach(Array(verse.words.enumerated()), id: \.offset) { _, word in
                                    WordView(word: word, onWordTextClicked: {
                                        onWordClick?(word)
                                    })
                                }
                            }
                        }
                        .padding(.vertical, verseVerticalPadding)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}
