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
        let formatted = parseHTML(result.definition)
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
    
    private struct FormattedDefinition {
        let attributedString: AttributedString
        let plainText: String
    }
    
    private func parseHTML(_ rawHtml: String) -> FormattedDefinition {
        var text = rawHtml
        
        // Remove search key prefix/suffix (case-insensitive)
        let keyLower = result.key.lowercased()
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix(keyLower) {
            text = String(text.dropFirst(keyLower.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if text.lowercased().hasSuffix(keyLower) {
            text = String(text.dropLast(keyLower.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Wrap in CSS stylesheet matching the application theme
        let style = """
        <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
            font-size: 13.5px;
            line-height: 1.5;
            color: #1c1c1e;
        }
        @media (prefers-color-scheme: dark) {
            body {
                color: #f2f2f7;
            }
        }
        .orth {
            font-weight: bold;
            font-size: 1.1em;
            color: #2f8ef4ff;
        }
        .pos {
            font-style: italic;
            font-weight: bold;
            color: #8e8e93;
        }
        .pron {
            color: #8e8e93;
            font-style: normal;
        }
        .def {
            display: inline;
        }
        .etym {
            font-style: italic;
            color: #48484a;
        }
        @media (prefers-color-scheme: dark) {
            .etym {
                color: #aeaeb2;
            }
        }
        .oVar {
            font-style: italic;
        }
        .persName {
            font-style: italic;
            font-weight: 500;
        }
        .quote {
            font-style: italic;
            display: inline;
        }
        .cit {
            display: block;
            margin: 4px 0 4px 12px;
            border-left: 2px solid rgba(128, 128, 128, 0.3);
            padding-left: 8px;
        }
        .sense {
            display: block;
            margin-top: 10px;
        }
        .number {
            font-weight: bold;
        }
        .entryFree {
            display: block;
            margin-bottom: 8px;
        }
        pre, tt {
            font-family: Menlo, Monaco, Consolas, monospace;
            font-size: 11.5px;
            background-color: rgba(128, 128, 128, 0.15);
            padding: 8px;
            border-radius: 6px;
            display: block;
            white-space: pre-wrap;
            margin: 8px 0;
        }
        a{
            color: #079af5ff;
            cursor: pointer;
            text-decoration: none;
        }
        </style>
        """
        
        let htmlContent = "\(style)<body>\(text)</body>"
        
        if let data = htmlContent.data(using: .utf8),
           let nsAttr = try? NSAttributedString(
               data: data,
               options: [
                   .documentType: NSAttributedString.DocumentType.html,
                   .characterEncoding: String.Encoding.utf8.rawValue
               ],
               documentAttributes: nil
           ) {
            return FormattedDefinition(attributedString: AttributedString(nsAttr), plainText: nsAttr.string)
        }
        
        return FormattedDefinition(attributedString: AttributedString(rawHtml), plainText: rawHtml)
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
