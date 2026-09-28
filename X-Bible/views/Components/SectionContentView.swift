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
    var onStrongsClicked: ((String) -> Void)? = nil

    @EnvironmentObject private var textConfigVM: TextConfigViewModel

    var body: some View {
        let config = textConfigVM.config
        let font = CGFloat(config.fontSize)

        // --- Derived typographic metrics ---
        // config.lineSpacing and config.wordSpacing are signed "steps"
        // around a neutral baseline of 0.
        let baseLineGap = font * 0.35
        let lineStep    = font * 0.15
        let lineSpacing = max(font * 0.05, baseLineGap + CGFloat(config.lineSpacing) * lineStep)


        let baseWordGap = font * 0.25
        let wordStep    = font * 0.10
        let wordSpacing = max(0, baseWordGap + CGFloat(config.wordSpacing) * wordStep)

        let sectionSpacing     = 0.0//font * 1.6 + CGFloat(config.lineSpacing) * font * 0.20
        let verseBlockSpacing  = 0.0//font * 0.9 + CGFloat(config.lineSpacing) * font * 0.10
        let titleBottomPadding = font * 0.4 + CGFloat(config.lineSpacing) * font * 0.08

        VStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                VStack(
                    alignment: section.textDirection == .rtl ? .trailing : .leading,
                    spacing: lineSpacing
                ) {
                    if !section.title.isEmpty {
                        FlowLayout(
                            spacing: wordSpacing,
                            lineSpacing: lineSpacing
                        ) {
                            ForEach(Array(section.title.enumerated()), id: \.offset) { _, item in
                                WordView(
                                    word: item,
                                    isTitle: true,
                                    onWordTextClicked: { word in onWordClick?(word) },
                                    onStrongsClicked: { strongs in onStrongsClicked?(strongs) }
                                )
                            }
                        }
                        .padding(.vertical, titleBottomPadding)
                        
                    }

                    ForEach(section.verses, id: \.osisId) { verse in
                        VerseView(
                            verse: verse,
                            direction: section.textDirection,
                            onWordTextClicked: { word in onWordClick?(word) },
                            onStrongsClicked: { strongs in onStrongsClicked?(strongs) }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        //.padding(.vertical, 20)
    }
}
