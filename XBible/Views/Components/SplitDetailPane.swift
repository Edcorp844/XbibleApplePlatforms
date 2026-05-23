//
//  SplitDetailPane.swift
//  XBible
//
//  Created by Zoe Brooklyn on 5/23/26.
//

import SwiftUI
import XbibleEngine

struct SplitDetailPane: View {
    @Binding var isPresented: Bool
    @Binding var selectedTab: StudyTab
    let width: CGFloat
    
    // Dictionary State
    @Binding var selectedWordForLookup: String
    @Binding var dictionaryResults: [XbibleEngine.DictionaryResult]
    let isDictionaryLoading: Bool
    let onWordClick: (XbibleEngine.Word) -> Void
    
    // Lexicon State
    @Binding var selectedStrongsForLookup: String
    @Binding var selectedLexiconModule: String
    let availableLexicons: [XbibleEngine.SwordModule]
    let lexiconResults: [LexiconResult] // Your flat lookup structure
    let isLexiconLoading: Bool
    let onLexiconModuleChanged: () -> Void
    
    // Commentary State
    @Binding var selectedCommentaryModule: String
    let availableCommentaries: [XbibleEngine.SwordModule]
    let commentaryResults: [XbibleEngine.Section]
    let isCommentaryLoading: Bool
    let onCommentaryModuleChanged: () -> Void
    let currentCommentaryReference: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Header: Segmented Control & Dismiss Button
            HStack(spacing: 12) {
                StudyToolsControl(
                    selection: $selectedTab,
                    items: StudyTab.allCases,
                    title: { $0.rawValue }
                )
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .help("Hide Split View")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Tab Contents
            ZStack {
                switch selectedTab {
                case .dictionary:
                    dictionaryTabContent
                case .lexicon:
                    lexiconTabContent
                case .commentary:
                    commentaryTabContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: width)
        .overlay(
            HStack {
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1)
                Spacer()
            }
        )
    }
    
    private func copyableText(for sections: [XbibleEngine.Section]) -> String {
        sections.map { section in
            let titleText = section.title.map { $0.text }.joined(separator: " ")
            let versesText = section.verses.map { verse in
                let verseNum = verse.number > 0 ? "[\(verse.number)] " : ""
                let wordsText = verse.words.map { $0.text }.joined(separator: " ")
                return "\(verseNum)\(wordsText)"
            }.joined(separator: "\n")
            return [titleText, versesText].filter { !$0.isEmpty }.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }
    
    // MARK: - Tab Content Views
    
    private var dictionaryTabContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if !selectedWordForLookup.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedWordForLookup)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: 24, height: 3)
                    }
                } else {
                    Text("Select a word to lookup")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            if isDictionaryLoading {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                Spacer()
            } else if selectedWordForLookup.isEmpty {
                dictionaryEmptyState
            } else if dictionaryResults.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No definitions found for \"\(selectedWordForLookup)\".")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(32)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Safe enumeration pattern avoids out-of-bounds index race conditions
                        ForEach(Array(dictionaryResults.enumerated()), id: \.offset) { _, result in
                            DictionaryResultRowView(result: result)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
    
    private var dictionaryEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "character.book.closed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .opacity(0.5)
            Text("Dictionary Lookup")
                .font(.title3)
                .fontWeight(.bold)
            Text("Click any word in the scripture view to automatically look up its definition across all matching installed dictionary modules.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Spacer()
        }
        .padding(32)
    }
    
    private var lexiconTabContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    Text("Lexicon")
                        .font(.headline)
                    Spacer()
                    if availableLexicons.isEmpty {
                        Text("No lexicons installed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Menu {
                            ForEach(availableLexicons, id: \.name) { module in
                                Button(action: {
                                    selectedLexiconModule = module.name
                                    onLexiconModuleChanged()
                                }) {
                                    HStack {
                                        Text(module.description.isEmpty ? module.name : module.description)
                                        if selectedLexiconModule == module.name {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(availableLexicons.first(where: { $0.name == selectedLexiconModule })?.description ?? selectedLexiconModule)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                        }
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                    }
                }
                
                if !selectedStrongsForLookup.isEmpty {
                    HStack {
                        Text("Strong's Code:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(selectedStrongsForLookup)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))
            
            Divider()
            
            if isLexiconLoading {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                Spacer()
            } else if selectedStrongsForLookup.isEmpty {
                lexiconEmptyState
            } else if lexiconResults.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No lexicon entries found for \"\(selectedStrongsForLookup)\" in \(selectedLexiconModule).")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(32)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(lexiconResults, id: \.resolvedKey) { result in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(result.resolvedKey)
                                        .font(.headline)
                                        .foregroundColor(.accentColor)
                                    
                                    if !result.isExactMatch {
                                        Text("(Closest Match)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                }
                                
                                Text(result.definition)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                                    .lineSpacing(4)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
    
    private var lexiconEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "abc")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .opacity(0.5)
            Text("Lexicon Study")
                .font(.title3)
                .fontWeight(.bold)
            Text("Click on a Strong's number below any Greek/Hebrew word to see its lexicon entry, morphological information, and detailed translation notes.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Spacer()
        }
        .padding(32)
    }
    
    private var commentaryTabContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    Text("Commentary")
                        .font(.headline)
                    Spacer()
                    if availableCommentaries.isEmpty {
                        Text("No commentaries installed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Menu {
                            ForEach(availableCommentaries, id: \.name) { module in
                                Button(action: {
                                    selectedCommentaryModule = module.name
                                    onCommentaryModuleChanged()
                                }) {
                                    HStack {
                                        Text(module.description.isEmpty ? module.name : module.description)
                                        if selectedCommentaryModule == module.name {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(availableCommentaries.first(where: { $0.name == selectedCommentaryModule })?.description ?? selectedCommentaryModule)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                        }
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                    }
                }
                
                HStack {
                    Text("Reference:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currentCommentaryReference)
                        .font(.caption)
                        .fontWeight(.bold)
                    Spacer()
                    if !commentaryResults.isEmpty {
                        Button(action: {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(copyableText(for: commentaryResults), forType: .string)
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))
            
            Divider()
            
            if isCommentaryLoading {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                Spacer()
            } else if selectedCommentaryModule.isEmpty {
                commentaryEmptyState
            } else if commentaryResults.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No commentary found for \"\(currentCommentaryReference)\" in \(selectedCommentaryModule).")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(32)
            } else {
                ScrollView {
                    SectionContentView(sections: commentaryResults, onWordClick: onWordClick)
                        .padding(16)
                }
            }
        }
    }
    
    private var commentaryEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "text.quote")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .opacity(0.5)
            Text("Commentaries")
                .font(.title3)
                .fontWeight(.bold)
            Text("Select or install a commentary module from the Store to read study notes, theological essays, and explanations for the active scripture chapter.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Spacer()
        }
        .padding(32)
    }
}

