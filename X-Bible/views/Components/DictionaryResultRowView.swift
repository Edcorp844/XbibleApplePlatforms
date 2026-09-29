//
//  DictionaryResultRowView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/23/26.
//
import SwiftUI
import XbibleEngine

struct DictionaryResultRowView: View {
    let result: XbibleEngine.DictionaryResult

    var body: some View {
        let formatted = parseHTML(result.definition, for: result.key)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.moduleName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
                
                CopyButton(text: "\(result.key)\n\n\(formatted.plainText)")
            }

            Text(result.key)
                .font(.title3)
                .fontWeight(.semibold)

            Text(formatted.attributedString)
                .font(.system(size: 14, design: .serif))
                .lineSpacing(4)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.02)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.05), lineWidth: 1))
    }
    
    
}

#if os(macOS)
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
#else
struct VisualEffectView: View {
    var body: some View {
        Color(uiColor: .systemBackground)
    }
}
#endif
