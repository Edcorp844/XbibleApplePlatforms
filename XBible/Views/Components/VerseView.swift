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
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("\(verse.number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.trailing, 4).baselineOffset(8)
            
            FlowLayout(spacing: 8) {
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
        }
    }
}
