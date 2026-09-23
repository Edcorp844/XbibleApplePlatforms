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
    var onWordTextClicked: ((XbibleEngine.Word) -> Void)? = nil
    var onStrongsClicked: ((String) -> Void)? = nil
    
    @EnvironmentObject private var textConfigVM: TextConfigViewModel
    
    var body: some View {
        let config = textConfigVM.config
        
        HStack(alignment: .top, spacing: 0) {
            Text("\(verse.number)")
                .font(.system(size: config.fontSize * 0.8, weight: .regular))
                .foregroundColor(.secondary)
                .padding(.trailing, 8)
                .baselineOffset(4)
             
            FlowLayout(spacing: CGFloat(config.wordSpacing)) {
                ForEach(0..<verse.words.count, id: \.self) { i in
                    let w = verse.words[i]

                    WordView(
                        word: w,
                        onWordTextClicked: {
                            onWordTextClicked?(w)
                        },
                        onStrongsClicked: { strong in
                            onStrongsClicked?(strong)
                        }
                    )
                }
            }
            // Apply line spacing as vertical spacing or padding between rows/items if supported by FlowLayout, or wrap accordingly
            .padding(.vertical, CGFloat(config.lineSpacing))
        }
    }
}
