//
//  AppTab.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 6/21/26.
//


import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case search = "Search"
    case bible = "Bible"
    case commentary = "Commentary"
    case dictionary = "Dictionary"
    case glossary = "Glossary"
    case dailyDevotional = "Devotional"
    case essays = "Essay"
    case generalBooks = "Book"
    case unorthodox = "Unordthodox"
    case maps = "Map"
    case lexicons = "Lexicon"
    
    var id: String { self.rawValue }
    
    var iconName: String {
        switch self {
        case .search: return "magnifyingglass"
        case .bible: return "book.closed"
        case .commentary: return "text.quote"
        case .dictionary: return "character.book.closed"
        case .glossary: return "character.book.closed"
        case .lexicons: return "abc"
        case .dailyDevotional: return "sun.max"
        case .essays: return "text.justify.left"
        case .generalBooks: return "books.vertical"
        case .unorthodox: return "exclamationmark.triangle"
        case .maps: return "map"
        }
    }
}

struct GridTabView: View {
    var onSelect: (AppTab) -> Void
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AppTab.allCases) { tab in
                Button(action: {
                    onSelect(tab)
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 24))
                            .frame(width: 56, height: 56)
                            .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(.secondarySystemFill))
                                    )
                        
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                }
                .buttonStyle(GridTabButtonStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
    }
}

struct GridTabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}


extension Color {
    #if os(iOS)
    static let fractionalBackground = UIColor.secondarySystemGroupedBackground
    #else
    static let fractionalBackground = NSColor.controlBackgroundColor
    #endif
}

#Preview {
    GridTabView(onSelect: {tab in
        print(tab)
    })
}
