//
//  StudyView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/21/26.
//

import SwiftUI
import XbibleEngine

typealias BibleSection = XbibleEngine.Section

struct StudyView: View {
    @EnvironmentObject var wrapper: SwordEngineWrapper
    
    // Selection State
    @State private var sections: [BibleSection] = []
    @State private var selectedModule: String = "KJV"
    @State private var selectedBook: String = "John"
    @State private var selectedChapter: Int = 1
    @State private var searchText: String = ""
    
    // Metadata lists from Rust
    @State private var availableModules: [XbibleEngine.SwordModule] = []
    @State private var availableBooks: [XbibleEngine.ModuleBook] = []
    
    // Popover Toggles
    @State private var showModulePicker = false
    @State private var showBookPicker = false
    @State private var showChapterPicker = false
    
    var body: some View {
        ScrollView {
            HStack {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 40) {
                    ForEach(0..<sections.count, id: \.self) { i in
                        let section = sections[i]
                        VStack(alignment: section.textDirection == .rtl ? .trailing : .leading, spacing: 20) {
                            if !section.title.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(0..<section.title.count, id: \.self) { j in
                                        WordView(word: section.title[j])
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            ForEach(section.verses, id: \.osisId) { verse in
                                VerseView(verse: verse)
                            }
                        }
                    }
                }
                .padding(40)
                .frame(minWidth: 400, maxWidth: 1200)
                Spacer(minLength: 0)
            }
        }
        .onAppear(perform: initializeData)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search...")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                
                // 1. Module Selection
                PopoverButton(label: selectedModule, icon: "book.fill", isPresented: $showModulePicker) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bible Versions").font(.headline).padding(.bottom, 8)
                        ForEach(availableModules, id: \.name) { module in
                            selectionRow(module.name, isSelected: selectedModule == module.name) {
                                selectedModule = module.name
                                showModulePicker = false
                            }
                        }
                    }
                    .padding()
                    .frame(width: 220)
                }

                // 2. Book Selection (Grid)
                PopoverButton(label: selectedBook, icon: "text.book.closed.fill", isPresented: $showBookPicker) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Book").font(.headline)
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                                ForEach(availableBooks, id: \.name) { book in
                                    selectionRow(book.name, isSelected: selectedBook == book.name) {
                                        selectedBook = book.name
                                        showBookPicker = false
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(width: 500, height: 400)
                }

                // 3. Chapter Selection (Number Grid)
                PopoverButton(label: "\(selectedChapter)", icon: "number", isPresented: $showChapterPicker) {
                    chapterPickerContent
                }
            }
        }.backgroundStyle(.clear)
        .onChange(of: selectedModule) { _ in updateBooks(); loadContent() }
        .onChange(of: selectedBook) { _ in selectedChapter = 1; loadContent() }
        .onChange(of: selectedChapter) { _ in loadContent() }
    }
    
    // --- UI HELPERS ---

    @ViewBuilder
    private var chapterPickerContent: some View {
        let chapters = availableBooks.first(where: { $0.name == selectedBook })?.chapters ?? []
        let total = max(1, chapters.count)
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Chapter").font(.headline)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                    ForEach(1...total, id: \.self) { ch in
                        chapterCell(for: ch)
                    }
                }
            }
        }
        .padding()
        .frame(width: 280, height: 350)
    }

    func chapterCell(for ch: Int) -> some View {
        Button(action: {
            selectedChapter = ch
            showChapterPicker = false
        }) {
            Text("\(ch)")
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(selectedChapter == ch ? Color.accentColor : Color.primary.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    func selectionRow(_ text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Color.accentColor : Color.clear)
                .contentShape(Rectangle())
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // --- LOGIC ---

    func initializeData() {
        guard let engine = wrapper.engine else { return }
        self.availableModules = engine.getAvailableModules()
        updateBooks()
        loadContent()
    }

    func updateBooks() {
        guard let engine = wrapper.engine else { return }
        let books = engine.getBooks(moduleName: selectedModule)
        self.availableBooks = books
        if !books.contains(where: { $0.name == selectedBook }) {
            selectedBook = books.first?.name ?? ""
            selectedChapter = 1
        }
    }

    func loadContent() {
        guard let engine = wrapper.engine, !selectedBook.isEmpty else { return }
        let ref = "\(selectedBook) \(selectedChapter)"
        let results = engine.getChapterContent(moduleName: selectedModule, reference: ref)
        DispatchQueue.main.async {
            self.sections = results
        }
    }
}

// MARK: - Custom Glass Components

struct PopoverButton<Content: View>: View {
    let label: String
    let icon: String
    @Binding var isPresented: Bool
    let content: () -> Content

    var body: some View {
        Button(action: { isPresented.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).fontWeight(.medium)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).opacity(0.5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            content()
        }
    }
}

// MARK: - Supporting Views (Word, Verse, Layout)

struct WordView: View {
    let word: XbibleEngine.Word
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(word.text)
                .font(.system(size: 17, design: .serif))
                .fontWeight(word.isBoldText ? .bold : .regular)
                .italic(word.isItalic)
                .foregroundColor(word.isRed ? .red : .primary)
            
            if let lex = word.lex, !lex.strongs.isEmpty || !lex.morph.isEmpty {
                HStack(spacing: 3) {
                    if let strong = lex.strongs.first {
                        Text(strong).font(.system(size: 9, weight: .bold, design: .monospaced))
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

struct VerseView: View {
    let verse: XbibleEngine.Verse
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("\(verse.number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.trailing, 4).baselineOffset(8)
            
            FlowLayout(spacing: 8) {
                ForEach(0..<verse.words.count, id: \.self) { i in
                    WordView(word: verse.words[i])
                }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(at: .zero, in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews)
        return result.size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        _ = layout(at: bounds.origin, in: bounds.width, subviews: subviews, place: true)
    }
    private func layout(at origin: CGPoint, in maxWidth: CGFloat, subviews: Subviews, place: Bool = false) -> (size: CGSize, lastY: CGFloat) {
        var x = origin.x, y = origin.y, rowHeight: CGFloat = 0, width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > origin.x + maxWidth {
                x = origin.x
                y += rowHeight + spacing
                rowHeight = 0
            }
            if place { subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified) }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - origin.x)
        }
        return (CGSize(width: width, height: y + rowHeight - origin.y), y + rowHeight)
    }
}
