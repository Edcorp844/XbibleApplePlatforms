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
    
    // 1. Make the closures optional by adding '?' and defaulting them to nil
    var onWordTextClicked: (() -> Void)? = nil
    var onStrongsClicked: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(word.text)
                .font(.system(size: 17, design: .serif))
                .fontWeight(word.isBoldText ? .bold : .regular)
                .italic(word.isItalic)
                .foregroundColor(word.isRed ? .red : .primary)
                .onTapGesture {
                    onWordTextClicked?()
                }
            
            if let lex = word.lex, !lex.strongs.isEmpty || !lex.morph.isEmpty {
                HStack(spacing: 3) {
                    if let strong = lex.strongs.first {
                        Text(strong)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            
                            .onTapGesture {
                                onStrongsClicked?(strong)
                            }
                    }
                    if let morph = lex.morph.first {
                        Text(morph).font(.system(size: 8)).foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Color.secondary.opacity(0.15)).cornerRadius(4)
            }
        }
    }
}
