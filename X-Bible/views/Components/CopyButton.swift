//
//  CopyButton.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/23/26.
//
import SwiftUI

struct CopyButton: View {
    let text: String
    @State private var isCopied = false
    
    var body: some View {
        Button(action: {
            #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(text, forType: .string)
            #else
            UIPasteboard.general.string = text
            #endif
            isCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isCopied = false
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                if isCopied {
                    Text("Copied")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(isCopied ? .green : .secondary)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(isCopied ? 0.08 : 0.04)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
