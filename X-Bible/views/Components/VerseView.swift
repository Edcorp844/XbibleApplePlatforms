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
        let isRTL = direction == .rtl

        HStack(alignment: .top, spacing: 0) {
            // Always first in source order
            verseNumber(config: config)

            FlowLayout(
                spacing: CGFloat(config.wordSpacing),
                layoutDirection: isRTL ? .rightToLeft : .leftToRight
            ) {
                ForEach(0..<verse.words.count, id: \.self) { i in
                    let w = verse.words[i]

                    WordView(
                        word: w,
                        onWordTextClicked: { onWordTextClicked?(w) },
                        onStrongsClicked: { strong in onStrongsClicked?(strong) }
                    )
                }
            }
            .padding(.vertical, CGFloat(config.lineSpacing))
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder
    private func verseNumber(config: TextConfig) -> some View {
        Text("\(verse.number)")
            .font(.system(size: config.fontSize * 0.8, weight: .regular))
            .foregroundColor(.secondary)
            .padding(.trailing, 8)          // ← always trailing
            .baselineOffset(4)
    }
}
