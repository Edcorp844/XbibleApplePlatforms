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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

    // MARK: - Body

    var body: some View {
        let config = textConfigVM.config

        // ── Compute once per render. Everything downstream uses these locals.
        let base = config.scaledPointSize(for: dynamicTypeSize)
        let fontSize: CGFloat = isTitle ? base * 1.1 : base
        let resolvedFont: Font = makeFont(size: fontSize, config: config)

        let badgeGap    = fontSize * 0.10
        let strongsSize = max(8, fontSize * 0.45)
        let morphSize   = max(7, fontSize * 0.40)

        // ── Pre-resolve style flags so the view tree stays flat.
        let isAdded      = word.isAdded
        let displayText  = renderText(word.text, isAdded: isAdded, style: config.addedWordsStyle)
        let italic       = shouldItalic(word: word, isAdded: isAdded, style: config.addedWordsStyle)
        let weight: Font.Weight = (isTitle || word.isBoldText) ? .semibold : .regular
        let textColor: Color = (config.showRedWords && word.isRed) ? .red : .primary

        VStack(alignment: .center, spacing: badgeGap) {

            Text(displayText)
                .font(resolvedFont)
                .fontWeight(weight)
                .italic(italic)
                .foregroundColor(textColor)
                .onTapGesture { onWordTextClicked?(word) }

            if config.showStrongs,
               let lex = word.lex,
               !lex.strongs.isEmpty || !lex.morph.isEmpty {

                HStack(spacing: fontSize * 0.08) {
                    if config.showStrongs, let strong = lex.strongs.first {
                        Text(strong)
                            .font(.system(size: strongsSize,
                                          weight: .bold,
                                          design: .monospaced))
                            .foregroundColor(.primary)
                            .onTapGesture { onStrongsClicked?(strong) }
                    }
                    if config.showMorph, let morph = lex.morph.first {
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

    // MARK: - Pure helpers (no view-tree side effects)

    @inline(__always)
    private func makeFont(size: CGFloat, config: TextConfig) -> Font {
        if config.useSystemFont {
            return .system(size: size, design: config.systemDesign)
        }
        if !config.fontPostScriptName.isEmpty,
           InstalledFonts.isInstalled(config.fontPostScriptName) {
            return .custom(config.fontPostScriptName, size: size)
        }
        return .system(size: size, design: config.systemDesign)
    }

    @inline(__always)
    private func renderText(_ base: String,
                            isAdded: Bool,
                            style: AddedWordsStyle) -> String {
        guard isAdded else { return base }
        switch style {
        case .brackets: return "[\(base)]"
        case .italic:   return base
        @unknown default: return base
        }
    }

    @inline(__always)
    private func shouldItalic(word: XbibleEngine.Word,
                              isAdded: Bool,
                              style: AddedWordsStyle) -> Bool {
        if word.isItalic { return true }
        if isAdded, style == .italic { return true }
        return false
    }
}
