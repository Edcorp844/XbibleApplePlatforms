//
//  SearchTabView.swift
//  X-Bible
//
//  Created by Zoe Brooklyn on 9/28/26.
//
//  Swift port of SearchView.kt.
//

import SwiftUI
import XbibleEngine

// MARK: - Search Tab View

struct SearchTabView: View {
    @Binding var tab: TabInstance

    /// Available Bible modules for the module picker chip.
    let availableModules: [XbibleEngine.SwordModule]

    /// Currently selected search strategy (owned by `StudyViewModel`).
    let searchType: SearchType

    /// Actions routed up to `StudyViewModel` / `StudyView`.
    var onSearch: (String) -> Void
    var onModuleChange: (String) -> Void
    var onReferenceClick: (String) -> Void
    var onCopyVerse: (String, [ModuleSection]) -> Void
    var onOpenInNewTab: (SearchHit) -> Void
    var onPreviewChapter: (String) -> Void
    var onLexiconLookup: (String) -> Void

    /// Local query mirror — keeps the field responsive while the
    /// model debounces / dispatches the actual search.
    @State private var query: String = ""

    var body: some View {
        VStack(spacing: 0) {
            queryField

            if tab.isSearching {
                ProgressView(value: tab.searchLoadProgress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 16)
            }

            resultsContent
        }
        .onAppear { query = tab.searchQuery }
        .onChange(of: tab.id) { _, _ in query = tab.searchQuery }
        .onChange(of: tab.searchQuery) { _, newValue in
            // Keep local state in sync when the model mutates the
            // query from outside (e.g. duplicateTab restoring state).
            if query != newValue { query = newValue }
        }
    }

    // MARK: - Query field

    private var queryField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                "Search \(tab.selectedModule.isEmpty ? "Bible" : tab.selectedModule)…",
                text: $query
            )
            .textFieldStyle(.plain)
            .submitLabel(.search)
            .onSubmit { onSearch(query) }

            if !query.isEmpty {
                Button {
                    query = ""
                    onSearch("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsContent: some View {
        if tab.searchResults.isEmpty,
           !tab.searchQuery.isEmpty,
           !tab.isSearching {
            noResults
        } else if tab.searchResults.isEmpty,
                  tab.searchQuery.isEmpty,
                  !tab.isSearching {
            emptyPrompt
        } else {
            resultsList
        }
    }

    private var noResults: some View {
        VStack(spacing: 6) {
            Text("No results for \"\(tab.searchQuery)\"")
                .foregroundStyle(.secondary)
            if !tab.selectedModule.isEmpty {
                Text("in \(tab.selectedModule) · \(searchType.displayName)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyPrompt: some View {
        ContentUnavailableView(
            "Search \(tab.selectedModule.isEmpty ? "the Bible" : tab.selectedModule)",
            systemImage: "magnifyingglass",
            description: Text("Enter a query to find verses across this module.")
        )
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(tab.searchResults, id: \.key) { hit in
                    SearchHitRow(
                        hit: hit,
                        content: tab.searchHitsContent[hit.key],
                        query: tab.searchQuery,
                        tint: TabType.search.tint,
                        onReferenceClick: { onReferenceClick(hit.key) },
                        onCopyVerse: { sections in onCopyVerse(hit.key, sections) },
                        onOpenInNewTab: { onOpenInNewTab(hit) },
                        onPreviewChapter: { onPreviewChapter(hit.key) },
                        onLexiconLookup: { onLexiconLookup(hit.key) }
                    )
                }
            }
            .padding(16)
        }
    }
}

// MARK: - One hit row

private struct SearchHitRow: View {
    let hit: SearchHit
    let content: [ModuleSection]?
    let query: String
    let tint: Color
    
    var onReferenceClick: () -> Void
    var onCopyVerse: ([ModuleSection]) -> Void
    var onOpenInNewTab: () -> Void
    var onPreviewChapter: () -> Void
    var onLexiconLookup: () -> Void
    
    private let actionButtonSize: CGFloat = 28

    
    private var tokens: [String] {
        query.split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // ── Reference headersys
            HStack {
                Text(hit.key)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            // ── Word-level highlight of the passage
            if let content, !content.isEmpty {
                highlightedWords(from: content)
                
                // ── Action row
                actionRow(content: content)
            } else {
                // Living-space placeholder while content resolves.
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 40)
            }
            
            Divider()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { if content != nil { onReferenceClick() } }
    }
    
    // MARK: - Word rendering
    
    @ViewBuilder
    private func highlightedWords(from content: [ModuleSection]) -> some View {
        let words = content.flatMap { $0.verses }.flatMap { $0.words }
        FlowLayout(spacing: 4, lineSpacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                let isMatch = tokens.contains { token in
                    word.text.range(of: token, options: .caseInsensitive) != nil
                }
                Text(word.text)
                    .font(.body)
                    .padding(.horizontal, isMatch ? 4 : 0)
                    .padding(.vertical, isMatch ? 2 : 0)
                    .background(
                        isMatch
                        ? Color.accentColor.opacity(0.5)
                        : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
    
    // MARK: - Actions
    
    @ViewBuilder
    private func actionRow(content: [ModuleSection]) -> some View {
        HStack(spacing: 8) {
            SearchActionButton(
                systemImage: "arrow.up.right.square",
                size: actionButtonSize,
                help: "Open in New Tab",
                action: onOpenInNewTab
            )
            
            SearchActionButton(
                systemImage: "doc.on.doc",
                size: actionButtonSize,
                help: "Copy Verse",
                action: { onCopyVerse(content) }
            )
            
            SearchActionButton(
                systemImage: "ellipsis",
                size: actionButtonSize,
                help: "More",
                action: onLexiconLookup
            )
            
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}


// MARK: - Reusable action box

/// A rounded-rectangle icon button with a fixed square footprint.
/// All search-hit action buttons use this so they stay visually
/// consistent regardless of icon glyph size.
private struct SearchActionButton: View {
    let systemImage: String
    let size: CGFloat
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 0.5)
                )
                .foregroundStyle(.secondary)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
