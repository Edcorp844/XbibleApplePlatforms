//
//  VerseView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/23/26.
//

import SwiftUI
import XbibleEngine

struct VerseView: View {
    let verse: XbibleEngine.Verse
    let direction: TextDirection
    var onWordTextClicked: ((XbibleEngine.Word) -> Void)? = nil
    var onStrongsClicked: ((String) -> Void)? = nil
    
    @EnvironmentObject private var textConfigVM: TextConfigViewModel
    
    var body: some View {
        let config = textConfigVM.config
        let font = CGFloat(config.fontSize)
        let isRTL = direction == .rtl
        
        let baseLineGap = font * 0.35
        let lineStep    = font * 0.15
        let lineSpacing = max(font * 0.05, baseLineGap + CGFloat(config.lineSpacing) * lineStep)
        
        let baseWordGap = font * 0.25
        let wordStep    = font * 0.10
        let wordSpacing = max(0, baseWordGap + CGFloat(config.wordSpacing) * wordStep)
        
        let verseRowPadding = font * 0.10 + CGFloat(config.lineSpacing) * font * 0.05
        
        HStack(alignment: .top, spacing: 0) {
#if os(macOS)
            verseNumber(config: config)
#endif
            
            FlowLayout(
                spacing: wordSpacing,
                lineSpacing: lineSpacing
            ) {
                ForEach(0..<verse.words.count, id: \.self) { i in
                    let w = verse.words[i]
                    
#if os(iOS)
                    if i == 0 { verseNumber(config: config) }
#endif
                    
                    WordView(
                        word: w,
                        onWordTextClicked: { word in onWordTextClicked?(word) },
                        onStrongsClicked: { strong in onStrongsClicked?(strong) }
                    )
                }
            }
           // .padding(.vertical, lineSpacing)
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
    }
    
    @ViewBuilder
    private func verseNumber(config: TextConfig) -> some View {
        Text("\(verse.number)")
            .font(.system(size: config.fontSize * 0.75, weight: .regular))
            .foregroundColor(.secondary)
#if os(macOS)
            .padding(.trailing, config.fontSize * 0.45)
#else
            .padding(.trailing, config.fontSize * 0.25)
#endif
            .baselineOffset(config.fontSize * 0.22)
    }
}
