//
//  StudyView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/21/26.
//

import SwiftUI
import XbibleEngine
import SwiftData


struct StudyView: View {
    @EnvironmentObject var wrapper: SwordEngineWrapper
    @Environment(\.modelContext) private var modelContext
    
    
    @State private var sections: [ModuleSection] = []
    @State private var searchText: String = ""
    
    // Metadata lists from Rust
    @State private var availableModules: [XbibleEngine.SwordModule] = []
    @State private var availableBooks: [XbibleEngine.ModuleBook] = []
    
    // Split View Layout State
    @State private var isSplitViewPresented = false
    @State private var detailWidth: CGFloat = 350
    @State private var selectedTab: StudyTab = .dictionary
    
    // Dictionary Lookup State
    @State private var selectedWordForLookup: String = ""
    @State private var dictionaryResults: [XbibleEngine.DictionaryResult] = []
    @State private var isDictionaryLoading = false
    
    // Lexicon Lookup State
    @State private var selectedStrongsForLookup: String = ""
    @State private var selectedLexiconModule: String = ""
    @State private var lexiconResults: [XbibleEngine.Section] = []
    @State private var availableLexicons: [XbibleEngine.SwordModule] = []
    @State private var isLexiconLoading = false
    
    // Commentary Lookup State
    @State private var selectedCommentaryModule: String = ""
    @State private var commentaryResults: [XbibleEngine.Section] = []
    @State private var availableCommentaries: [XbibleEngine.SwordModule] = []
    @State private var isCommentaryLoading = false
    @State private var currentCommentaryReference: String = ""
    
    init() { }
    
    // Popover Toggles
    @State private var showModulePicker = false
    @State private var showBookPicker = false
    @State private var showChapterPicker = false
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
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
                                                self.wordView(for: section, at: j)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .center)
                                    }
                                    ForEach(section.verses, id: \.osisId) { verse in
                                        VerseView(
                                            verse: verse,
                                            onWordTextClicked: { word in
                                                lookupWord(word)
                                            },
                                            onStrongsClicked: { strongs in
                                                lookupStrongs(strongs)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(40)
                        .frame(minWidth: 400, maxWidth: 1200)
                        Spacer(minLength: 0)
                    }
                }
                
                // Side Navigation Buttons
                HStack {
                    NavigationRectButton(icon: "chevron.left", action: goToPreviousChapter, isDisabled: !canGoToPrevious(), isSide: true)
                        .padding(.leading, 8)
                    Spacer()
                    NavigationRectButton(icon: "chevron.right", action: goToNextChapter, isDisabled: !canGoToNext(), isSide: true)
                        .padding(.trailing, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Draggable Split View
            if isSplitViewPresented {
                SplitDivider(detailWidth: $detailWidth)
                
                SplitDetailPane(
                    isPresented: $isSplitViewPresented,
                    selectedTab: $selectedTab,
                    width: detailWidth,
                    selectedWordForLookup: $selectedWordForLookup,
                    dictionaryResults: $dictionaryResults,
                    isDictionaryLoading: isDictionaryLoading,
                    onWordClick: { word in
                        lookupWord(word)
                    },
                    selectedStrongsForLookup: $selectedStrongsForLookup,
                    selectedLexiconModule: $selectedLexiconModule,
                    availableLexicons: availableLexicons,
                    lexiconResults: lexiconResults,
                    isLexiconLoading: isLexiconLoading,
                    onLexiconModuleChanged: {
                        loadLexiconContent()
                    },
                    selectedCommentaryModule: $selectedCommentaryModule,
                    availableCommentaries: availableCommentaries,
                    commentaryResults: commentaryResults,
                    isCommentaryLoading: isCommentaryLoading,
                    onCommentaryModuleChanged: {
                        loadCommentaryContent()
                    },
                    currentCommentaryReference: currentCommentaryReference
                )
                .transition(.move(edge: .trailing))
            }
        }
        .onAppear(perform: initializeData)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search...")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                
                // 1. Module Selection
                PopoverButton(
                    label: wrapper.selectedModule,
                    isPresented: $showModulePicker
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bible Versions").font(.headline).padding(.bottom, 8)
                        ScrollView{
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                                ForEach(availableModules, id: \.name) { module in
                                    moduleSelectionRow(
                                        module.name,
                                        language: module.language,
                                        isSelected: wrapper.selectedModule == module.name
                                    ) {
                                        wrapper.selectedModule = module.name
                                        showModulePicker = false
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(width: 220)
                }
                
                // 2. Book Selection (Grid)
                PopoverButton(label: wrapper.selectedBook, isPresented: $showBookPicker) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Book").font(.headline)
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                                ForEach(availableBooks, id: \.name) { book in
                                    selectionRow(book.name, isSelected: wrapper.selectedBook == book.name) {
                                        wrapper.selectedBook = book.name
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
                PopoverButton(label: "\(wrapper.selectedChapter)", isPresented: $showChapterPicker) {
                    chapterPickerContent
                }
            }
            
        }
        .backgroundStyle(.clear)
        .onChange(of: wrapper.selectedModule) { _ in updateBooks() }
        .onChange(of: wrapper.selectedBook) { _ in
            wrapper.selectedChapter = 1
            loadContent()
        }
        .onChange(of: wrapper.selectedChapter) { _ in loadContent() }
        .onChange(of: wrapper.engineVersion) { _ in initializeData() }
    }
    
    
    // --- UI HELPERS ---

    @ViewBuilder
    private func wordView(for section: ModuleSection, at index: Int) -> some View {
        let currentWord = section.title[index]
        
        return WordView(
            word: currentWord,
            onWordTextClicked: {
                self.lookupWord(currentWord)
            }
        )
    }

    @ViewBuilder
    private var chapterPickerContent: some View {
        let chapters = availableBooks.first(where: { $0.name == wrapper.selectedBook })?.chapters ?? []
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
            wrapper.selectedChapter = ch
            showChapterPicker = false
        }) {
            Text("\(ch)")
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(wrapper.selectedChapter == ch ? Color.accentColor : Color.primary.opacity(0.1))
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
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    func moduleSelectionRow(_ version: String, language: String,isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading){
                Text(version)
                Text(language)
                    .font(.system(.caption))
                    .foregroundColor(.secondary)
                    
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor : Color.clear)
            .contentShape(Rectangle())
            .cornerRadius(8)
            
        }
        .buttonStyle(.plain)
    }

    // --- LOGIC ---

    func initializeData() {
        guard let engine = wrapper.engine else { return }
        
        wrapper.engineQueue.async {
            let modules = engine.getBibleModules()
            let lexicons = engine.getLexiconModules()
            let commentaries = engine.getCommentaryModules()
            
            DispatchQueue.main.async {
                self.availableModules = modules
                
                // If current selected module is not in the installed list, pick the first one
                if !modules.contains(where: { $0.name == wrapper.selectedModule }) {
                    if let first = modules.first?.name {
                        wrapper.selectedModule = first
                    }
                }
                
                self.availableLexicons = lexicons
                if self.selectedLexiconModule.isEmpty || !lexicons.contains(where: { $0.name == self.selectedLexiconModule }) {
                    self.selectedLexiconModule = lexicons.first?.name ?? ""
                }
                
                self.availableCommentaries = commentaries
                if self.selectedCommentaryModule.isEmpty || !commentaries.contains(where: { $0.name == self.selectedCommentaryModule }) {
                    self.selectedCommentaryModule = commentaries.first?.name ?? ""
                }
                
                self.updateBooks()
                self.loadCommentaryContent()
            }
        }
    }

    func updateBooks() {
        guard let engine = wrapper.engine else { return }
        let currentModule = wrapper.selectedModule
        
        wrapper.engineQueue.async {
            let books = engine.getBooks(moduleName: currentModule)
            
            DispatchQueue.main.async {
                self.availableBooks = books
                if !books.contains(where: { $0.name == wrapper.selectedBook }) {
                    wrapper.selectedBook = books.first?.name ?? ""
                    wrapper.selectedChapter = 1
                }
                self.loadContent()
            }
        }
    }

    func loadContent() {
        guard let engine = wrapper.engine, !wrapper.selectedBook.isEmpty else { return }
        let currentModule = wrapper.selectedModule
        let ref = "\(wrapper.selectedBook) \(wrapper.selectedChapter)"
        
        wrapper.engineQueue.async {
            let results = engine.getChapterContent(moduleName: currentModule, reference: ref)
            let show = engine.getContent(moduleName: currentModule, reference: ref)
            
            print("Content: \(show)")
            
            DispatchQueue.main.async {
                self.sections = results
                self.loadCommentaryContent()
            }
        }
    }

    // --- LOOKUP ACTIONS ---

    func lookupWord(_ word: XbibleEngine.Word) {
        let cleanWord = word.text.trimmingCharacters(in: .punctuationCharacters)
        guard !cleanWord.isEmpty else { return }
        
        selectedWordForLookup = cleanWord
        selectedTab = .dictionary
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isSplitViewPresented = true
        }
        isDictionaryLoading = true
        
        let query = DictionaryQuery(
            word: cleanWord,
            strongs: [],
            language: word.language
        )
        
        wrapper.engineQueue.async {
            guard let engine = wrapper.engine else { return }
            let response = engine.lookupDictionary(query: query)
            
            DispatchQueue.main.async {
                self.dictionaryResults = response.results
                self.isDictionaryLoading = false
            }
        }
    }

    func lookupStrongs(_ strongsCode: String) {
        guard !strongsCode.isEmpty else { return }
        
        selectedStrongsForLookup = strongsCode
        selectedTab = .lexicon
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isSplitViewPresented = true
        }
        
        if availableLexicons.isEmpty {
            loadLexiconsMetadata {
                self.loadLexiconContent()
            }
        } else {
            self.loadLexiconContent()
        }
    }

    func loadLexiconsMetadata(completion: (() -> Void)? = nil) {
        wrapper.engineQueue.async {
            guard let engine = wrapper.engine else { return }
            let lexicons = engine.getLexiconModules()
            
            DispatchQueue.main.async {
                self.availableLexicons = lexicons
                if self.selectedLexiconModule.isEmpty || !lexicons.contains(where: { $0.name == self.selectedLexiconModule }) {
                    self.selectedLexiconModule = lexicons.first?.name ?? ""
                }
                completion?()
            }
        }
    }

    func loadLexiconContent() {
        guard !selectedLexiconModule.isEmpty && !selectedStrongsForLookup.isEmpty else {
            self.lexiconResults = []
            return
        }
        
        isLexiconLoading = true
        let moduleName = selectedLexiconModule
        let reference = selectedStrongsForLookup
        
        wrapper.engineQueue.async {
            guard let engine = wrapper.engine else { return }
            let results = engine.getContent(moduleName: moduleName, reference: reference)
            
            DispatchQueue.main.async {
                self.lexiconResults = results
                self.isLexiconLoading = false
            }
        }
    }

    func loadCommentariesMetadata(completion: (() -> Void)? = nil) {
        wrapper.engineQueue.async {
            guard let engine = wrapper.engine else { return }
            let commentaries = engine.getCommentaryModules()
            
            DispatchQueue.main.async {
                self.availableCommentaries = commentaries
                if self.selectedCommentaryModule.isEmpty || !commentaries.contains(where: { $0.name == self.selectedCommentaryModule }) {
                    self.selectedCommentaryModule = commentaries.first?.name ?? ""
                }
                completion?()
            }
        }
    }

    func loadCommentaryContent() {
        guard !selectedCommentaryModule.isEmpty else {
            self.commentaryResults = []
            return
        }
        
        isCommentaryLoading = true
        let moduleName = selectedCommentaryModule
        let reference = "\(wrapper.selectedBook) \(wrapper.selectedChapter)"
        currentCommentaryReference = reference
        
        wrapper.engineQueue.async {
            guard let engine = wrapper.engine else { return }
            let results = engine.getChapterContent(moduleName: moduleName, reference: reference)
            
            DispatchQueue.main.async {
                self.commentaryResults = results
                self.isCommentaryLoading = false
            }
        }
    }

    // --- NAVIGATION LOGIC ---

    func canGoToPrevious() -> Bool {
        guard let currentIndex = availableBooks.firstIndex(where: { $0.name == wrapper.selectedBook }) else { return false }
        return wrapper.selectedChapter > 1 || currentIndex > 0
    }

    func canGoToNext() -> Bool {
        guard let currentIndex = availableBooks.firstIndex(where: { $0.name == wrapper.selectedBook }) else { return false }
        let chapters = availableBooks[currentIndex].chapters
        return wrapper.selectedChapter < chapters.count || currentIndex < availableBooks.count - 1
    }

    func goToPreviousChapter() {
        if wrapper.selectedChapter > 1 {
            wrapper.selectedChapter -= 1
        } else {
            guard let currentIndex = availableBooks.firstIndex(where: { $0.name == wrapper.selectedBook }), currentIndex > 0 else { return }
            let prevBook = availableBooks[currentIndex - 1]
            wrapper.selectedBook = prevBook.name
            wrapper.selectedChapter = max(1, prevBook.chapters.count)
        }
    }

    func goToNextChapter() {
        guard let currentIndex = availableBooks.firstIndex(where: { $0.name == wrapper.selectedBook }) else { return }
        let currentBook = availableBooks[currentIndex]
        if wrapper.selectedChapter < currentBook.chapters.count {
            wrapper.selectedChapter += 1
        } else {
            guard currentIndex < availableBooks.count - 1 else { return }
            let nextBook = availableBooks[currentIndex + 1]
            wrapper.selectedBook = nextBook.name
            wrapper.selectedChapter = 1
        }
    }
}

// MARK: - Custom Glass Components

struct PopoverButton<Content: View>: View {
    let label: String
    @Binding var isPresented: Bool
    let content: () -> Content

    var body: some View {
        Button(action: { isPresented.toggle() }) {
            HStack(spacing: 6) {
                Text(label).fontWeight(.medium)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).opacity(0.5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            content()
        }
    }
}

struct NavigationRectButton: View {
    let icon: String
    let action: () -> Void
    let isDisabled: Bool
    var isSide: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: isSide ? 18 : 11, weight: .bold))
                .frame(width: 28, height: 36)
                .background(RoundedRectangle(cornerRadius: 20).fill(.thinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                .opacity(isDisabled ? 0.2 : 0.8)
                
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Split View Supporting Views & Enums

enum StudyTab: String, CaseIterable, Identifiable {
    case dictionary = "Dictionary"
    case lexicon = "Lexicon"
    case commentary = "Commentary"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .dictionary: return "character.book.closed"
        case .lexicon: return "abc"
        case .commentary: return "text.quote"
        }
    }
}
