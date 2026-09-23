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
    
    // Read the global environment view model
    @EnvironmentObject private var textConfigVM: TextConfigViewModel
    
    var onWordTextClicked: (() -> Void)? = nil
    var onStrongsClicked: ((String) -> Void)? = nil

    init(
        word: XbibleEngine.Word,
        isTitle: Bool = false,
        onWordTextClicked: (() -> Void)? = nil,
        onStrongsClicked: ((String) -> Void)? = nil
    ) {
        self.word = word
        self.isTitle = isTitle
        self.onWordTextClicked = onWordTextClicked
        self.onStrongsClicked = onStrongsClicked
    }

    private var activeFontSize: CGFloat {
        let baseSize = CGFloat(textConfigVM.config.fontSize)
        return isTitle ? baseSize * 1.25 : baseSize
    }

    var body: some View {
        let dbConfig = textConfigVM.config
        let fontSize = activeFontSize
        let verticalSpacing = CGFloat(dbConfig.lineSpacing) * 2

        VStack(alignment: .center, spacing: verticalSpacing) {
            // Main Scripture Word Layout Node
            Text(word.text)
                .font(.system(size: fontSize, design: dbConfig.useSystemFont ? dbConfig.systemDesign : .serif))
                .fontWeight((isTitle || word.isBoldText) ? .bold : .regular)
                .italic(word.isItalic)
                .foregroundColor((dbConfig.showRedWords && word.isRed) ? .red : .primary)
                .onTapGesture {
                    onWordTextClicked?()
                }
             
            // Strong's Tag Metadata Container (driven by global configuration)
            if dbConfig.showStrongs, let lex = word.lex, !lex.strongs.isEmpty || !lex.morph.isEmpty {
                HStack(spacing: 3) {
                    if dbConfig.showStrongs, let strong = lex.strongs.first {
                        Text(strong)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .onTapGesture {
                                onStrongsClicked?(strong)
                            }
                    }
                    if dbConfig.showMorph, let morph = lex.morph.first {
                        Text(morph)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
            }
        }
    }
}
