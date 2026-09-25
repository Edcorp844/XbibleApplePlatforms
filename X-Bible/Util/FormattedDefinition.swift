//
//  FormattedDefinition.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/25/26.
//

import SwiftUI

struct FormattedDefinition {
    let attributedString: AttributedString
    let plainText: String
}

enum DefinitionFormatter {

    /// Produces an AttributedString that closely matches the Android/Kotlin rendering.
    static func format(html rawHtml: String, searchKey: String) -> FormattedDefinition {
        var text = rawHtml.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Strip the search key from the beginning / end (case-insensitive)
        let keyLower = searchKey.lowercased()
        if text.lowercased().hasPrefix(keyLower) {
            text = String(text.dropFirst(keyLower.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if text.lowercased().hasSuffix(keyLower) {
            text = String(text.dropLast(keyLower.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 2. Pre-process exactly like the Kotlin side
        let processed = preprocess(text)

        // 3. Minimal CSS that the NSAttributedString HTML parser actually understands
        let style = """
        <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
            font-size: 15px;
            line-height: 1.45;
        }
        blockquote {
            margin: 6px 0 6px 12px;
            padding-left: 10px;
            border-left: 3px solid #8e8e93;
        }
        </style>
        """

        let fullHTML = "\(style)<body>\(processed)</body>"

        guard let data = fullHTML.data(using: .utf8),
              let nsAttr = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return FormattedDefinition(
                attributedString: AttributedString(rawHtml),
                plainText: rawHtml
            )
        }

        // Convert to SwiftUI AttributedString and force the body colour
        // so it respects the current colour scheme.
        var result = AttributedString(nsAttr)
        result.foregroundColor = .primary

        return FormattedDefinition(
            attributedString: result,
            plainText: nsAttr.string
        )
    }

    // MARK: - Pre-processing (mirrors the Kotlin logic)

    private static func preprocess(_ html: String) -> String {
        var t = html

        // orth → bold + accent colour (inline style the parser understands)
        t = t.replacingOccurrences(
            of: #"class="orth""#,
            with: #"style="font-weight:bold; font-size:1.1em; color:#007AFF""#,
            options: .regularExpression
        )

        // pos → italic + secondary colour
        t = t.replacingOccurrences(
            of: #"class="pos""#,
            with: #"style="font-style:italic; font-weight:600; color:#8E8E93""#,
            options: .regularExpression
        )

        // pron
        t = t.replacingOccurrences(
            of: #"class="pron""#,
            with: #"style="color:#8E8E93""#,
            options: .regularExpression
        )

        // etym
        t = t.replacingOccurrences(
            of: #"class="etym""#,
            with: #"style="font-style:italic; color:#636366""#,
            options: .regularExpression
        )

        // oVar / persName / quote → italic
        t = t.replacingOccurrences(
            of: #"class="(oVar|persName|quote)""#,
            with: #"style="font-style:italic""#,
            options: .regularExpression
        )

        // number → bold
        t = t.replacingOccurrences(
            of: #"class="number""#,
            with: #"style="font-weight:bold""#,
            options: .regularExpression
        )

        // Convert citation blocks into real <blockquote>
        // (this is what gives the left stripe + indentation)
        t = t.replacingOccurrences(
            of: #"<div class="cit">"#,
            with: "<blockquote>",
            options: .caseInsensitive
        )
        // Only close the ones we opened (simple heuristic)
        t = t.replacingOccurrences(
            of: #"</div>"#,
            with: "</blockquote>",
            options: .caseInsensitive
        )

        // Clean any remaining class="cit"
        t = t.replacingOccurrences(
            of: #"class="cit""#,
            with: "",
            options: .regularExpression
        )

        // sense / entryFree → block with a little spacing
        t = t.replacingOccurrences(
            of: #"class="sense""#,
            with: #"style="display:block; margin-top:10px""#,
            options: .regularExpression
        )
        t = t.replacingOccurrences(
            of: #"class="entryFree""#,
            with: #"style="display:block; margin-bottom:8px""#,
            options: .regularExpression
        )

        return t
    }
}

// MARK: - Convenience for views

extension View {
    /// Drop-in replacement for the old parseHTML helper.
    func parseHTML(_ rawHtml: String, for searchKey: String) -> FormattedDefinition {
        DefinitionFormatter.format(html: rawHtml, searchKey: searchKey)
    }
}
