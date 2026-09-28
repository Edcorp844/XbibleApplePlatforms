//
//  WordView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/23/26.
//

import SwiftUI
import XbibleEngine

struct WordView: View {
    let word: XbibleEngine.Word
    var isTitle: Bool

    @EnvironmentObject private var textConfigVM: TextConfigViewModel

    var onWordTextClicked: ((Word) -> Void)? = nil
    var onStrongsClicked: ((String) -> Void)? = nil

    init(
        word: XbibleEngine.Word,
        isTitle: Bool = false,
        onWordTextClicked: ((Word) -> Void)? = nil,
        onStrongsClicked: ((String) -> Void)? = nil
    ) {
        self.word = word
        self.isTitle = isTitle
        self.onWordTextClicked = onWordTextClicked
        self.onStrongsClicked = onStrongsClicked
    }

    private var activeFontSize: CGFloat {
        let baseSize = CGFloat(textConfigVM.config.fontSize)
        return isTitle ? baseSize * 1.1 : baseSize
    }

    // MARK: - Added-words handling

    /// Matches the Kotlin `WordConfig.addedWordsStyle`.
    /// `word.isAdded` should come from your engine — swap the property
    /// name if your `Word` type uses a different flag (e.g. `isAddedText`,
    /// `isSupplied`, `added`).
    private var isAddedWord: Bool {
        word.isAdded
    }

    /// The displayed string, with brackets applied when the style calls for it.
    private var displayedText: String {
        let base = word.text
        guard isAddedWord else { return base }

        switch textConfigVM.config.addedWordsStyle {
        case .brackets:
            return "[\(base)]"
        case .italic:
            return base
        @unknown default:
            return base
        }
    }

    /// Whether the word should render italic.
    /// Italic is true if the word is natively italic OR if the
    /// "added words" style asks for italics and this word is added.
    private var shouldRenderItalic: Bool {
        if word.isItalic { return true }
        if isAddedWord, textConfigVM.config.addedWordsStyle == .italic {
            return true
        }
        return false
    }

    // MARK: - Body

    var body: some View {
        let dbConfig = textConfigVM.config
        let fontSize = activeFontSize

        let badgeGap = fontSize * 0.10
        let strongsSize = max(8, fontSize * 0.45)
        let morphSize   = max(7, fontSize * 0.40)

        VStack(alignment: .center, spacing: badgeGap) {

            Text(displayedText)
                .font(
                    .system(
                        size: fontSize,
                        design: dbConfig.useSystemFont ? dbConfig.systemDesign : .serif
                    )
                )
                .fontWeight((isTitle || word.isBoldText) ? .semibold : .regular)
                .italic(shouldRenderItalic)
                .foregroundColor((dbConfig.showRedWords && word.isRed) ? .red : .primary)
                .onTapGesture {
                    onWordTextClicked?(word)
                }

            if dbConfig.showStrongs,
               let lex = word.lex,
               !lex.strongs.isEmpty || !lex.morph.isEmpty {

                HStack(spacing: fontSize * 0.08) {
                    if dbConfig.showStrongs, let strong = lex.strongs.first {
                        Text(strong)
                            .font(.system(size: strongsSize, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .onTapGesture {
                                onStrongsClicked?(strong)
                            }
                    }
                    if dbConfig.showMorph, let morph = lex.morph.first {
                        Text(morph)
                            .font(.system(size: morphSize))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, word.isPunctuation ? 0.0 : fontSize * 0.18)
                .padding(.vertical, fontSize * 0.05)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(fontSize * 0.18)
            }
        }
    }
}
