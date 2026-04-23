//
//  LanguageSection.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/23/26.
//

import SwiftUI
import XbibleEngine

struct LanguageSection<BookView: View>: View {
    let langCode: String
    let count: Int
    let modules: [XbibleEngine.SwordModule]
    let bookViewBuilder: (XbibleEngine.SwordModule) -> BookView
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: toggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Locale.current.localizedString(forLanguageCode: langCode) ?? langCode.uppercased())
                            .font(.headline)
                        Text("\(count) \(count == 1 ? "module" : "modules")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0)) // Animated Chevron
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Collapsible Content
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 20) {
                        ForEach(modules, id: \.name) { module in
                            bookViewBuilder(module)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider()
                .padding(.horizontal, 20)
                .opacity(0.3)
        }
    }
}
