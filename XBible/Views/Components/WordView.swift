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
    let config: Configuration
    
    var onWordTextClicked: (() -> Void)? = nil
    var onStrongsClicked: ((String) -> Void)? = nil

    // Initialize with a default config instance so your current layouts won't break
    init(
        word: XbibleEngine.Word,
        config: Configuration = .default,
        onWordTextClicked: (() -> Void)? = nil,
        onStrongsClicked: ((String) -> Void)? = nil
    ) {
        self.word = word
        self.config = config
        self.onWordTextClicked = onWordTextClicked
        self.onStrongsClicked = onStrongsClicked
    }

    var body: some View {
        VStack(alignment: .center, spacing: config.verticalSpacing) {
            // Main Scripture Word Layout Node
            Text(word.text)
                .font(.system(size: config.fontSize, design: config.fontDesign))
                .fontWeight(word.isBoldText ? .bold : .regular)
                .italic(word.isItalic)
                .foregroundColor(word.isRed ? config.redWordsColor : config.primaryTextColor)
                .onTapGesture {
                    onWordTextClicked?()
                }
            
            // Strong's Tag Metadata Container
            if config.showStrongsTags, let lex = word.lex, !lex.strongs.isEmpty || !lex.morph.isEmpty {
                HStack(spacing: 3) {
                    if let strong = lex.strongs.first {
                        Text(strong)
                            .font(.system(size: config.strongsFontSize, weight: .bold, design: .monospaced))
                            .foregroundColor(config.strongsTagColor)
                            .onTapGesture {
                                onStrongsClicked?(strong)
                            }
                    }
                    if let morph = lex.morph.first {
                        Text(morph)
                            .font(.system(size: config.morphFontSize))
                            .foregroundColor(config.morphTagColor)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(config.tagBackgroundColor)
                .cornerRadius(4)
            }
        }
    }
}

// MARK: - Configuration Structure

extension WordView {
    struct Configuration {
        // Text Size and Design Configuration
        var fontSize: CGFloat = 17
        var fontDesign: Font.Design = .serif
        var verticalSpacing: CGFloat = 2
        
        // Color Configuration Overrides
        var primaryTextColor: Color = .primary
        var redWordsColor: Color = .red
        
        // Metadata Layer Configuration Toggle
        var showStrongsTags: Bool = true
        var strongsFontSize: CGFloat = 9
        var morphFontSize: CGFloat = 8
        
        // Metadata Colors
        var strongsTagColor: Color = .primary
        var morphTagColor: Color = .secondary
        var tagBackgroundColor: Color = Color.secondary.opacity(0.15)
        
        /// Standard configuration defaults matching original look
        static let `default` = Configuration()
        
        /// Example preset configuration for a compact, secondary layout
        static let compactNotes = Configuration(
            fontSize: 14,
            fontDesign: .serif,
            verticalSpacing: 1,
            primaryTextColor: .secondary,
            showStrongsTags: false
        )
    }
}
