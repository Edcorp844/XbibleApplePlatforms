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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let config = textConfigVM.config

        // ── Resolve point size once, from the same path WordView uses.
        //    This is `systemBody × (1 + fontSizePercent/100)`, clamped.
        let font = config.scaledPointSize(for: dynamicTypeSize)

        let isRTL = direction == .rtl

        // ── Layout math now derives from `font` (already Dynamic-Type
        //    scaled), so the rhythm stays proportional at every size.
        let baseLineGap = font * 0.35
        let lineStep    = font * 0.15
        let lineSpacing = max(font * 0.05,
                              baseLineGap + CGFloat(config.lineSpacing) * lineStep)

        let baseWordGap = font * 0.25
        let wordStep    = font * 0.10
        let wordSpacing = max(0,
                              baseWordGap + CGFloat(config.wordSpacing) * wordStep)

        let verseSpacing = CGFloat(config.verseSpacing) * lineSpacing

        HStack(alignment: .top, spacing: 0) {
#if os(macOS)
            verseNumber(pointSize: font)
#endif

            FlowLayout(
                spacing: wordSpacing,
                lineSpacing: lineSpacing
            ) {
                ForEach(0..<verse.words.count, id: \.self) { i in
                    let w = verse.words[i]

#if os(iOS)
                    if i == 0 { verseNumber(pointSize: font) }
#endif

                    WordView(
                        word: w,
                        onWordTextClicked: { word in onWordTextClicked?(word) },
                        onStrongsClicked: { strong in onStrongsClicked?(strong) }
                    )
                }
            }
            .padding(.bottom, verseSpacing)
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
    }

    // MARK: - Verse number

    @ViewBuilder
    private func verseNumber(pointSize: CGFloat) -> some View {
        Text("\(verse.number)")
            .font(.system(size: pointSize * 0.75, weight: .regular))
            .foregroundColor(.secondary)
#if os(macOS)
            .padding(.trailing, pointSize * 0.45)
#else
            .padding(.trailing, pointSize * 0.25)
#endif
            .baselineOffset(pointSize * 0.22)
    }
}
