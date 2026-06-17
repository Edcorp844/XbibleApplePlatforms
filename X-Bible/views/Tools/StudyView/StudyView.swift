//  StudyView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/21/26.
//

import SwiftUI
import XbibleEngine
import SwiftData

#if os(macOS)
import AppKit
#endif

struct StudyView: View {
    @EnvironmentObject var wrapper: SwordEngineWrapper
    @Environment(\.modelContext) private var modelContext
    
    @FocusState private var isStudyViewFocused: Bool
    
    @State private var sections: [ModuleSection] = []
    @State private var searchText: String = ""
    
    // Metadata lists from Rust
    @State private var availableModules: [XbibleEngine.SwordModule] = []
    @State private var availableBooks: [XbibleEngine.ModuleBook] = []
    
    // Split View Layout State
    @State var isSplitViewPresented = false
    @State private var detailWidth: CGFloat = 350
    @State private var selectedTab: StudyTab = .dictionary
    
    // Dictionary Lookup State
    @State private var selectedWordForLookup: String = ""
    @State private var dictionaryResults: [XbibleEngine.DictionaryResult] = []
    @State private var isDictionaryLoading = false
    
    // Lexicon Lookup State
    @State private var selectedStrongsForLookup: String = ""
    @State private var selectedLexiconModule: String = ""
    @State private var lexiconResults: [XbibleEngine.LexiconResult] = []
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
    
    @State private var statusMessage = "Ready"
    
    var body: some View {
        // --- NATIVE SWIFTUI TOUCH BAR LAYOUT ---
#if os(macOS)
        let bibleStudyTouchBar = Group {
            Group {
                Button(action: {
                    statusMessage = "Previous Chapter (Touch Bar)"
                    goToPreviousChapter()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .padding()
                }
                .cornerRadius(8)
                .disabled(!canGoToPrevious())
                .touchBarItemPresence(.required("xbible.study.prevChapter"))
                
                Button(action: {
                    statusMessage = "Next Chapter (Touch Bar)"
                    goToNextChapter()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .padding()
                }
                .cornerRadius(8)
                .disabled(!canGoToNext())
                .touchBarItemPresence(.required("xbible.study.nextChapter"))
            }
            
            Spacer()
            
            Group {
                Button(action: {
                    statusMessage = "Search triggered (Touch Bar)"
                    print("Search triggered via Touch Bar")
                }) {
                    Label("Search", systemImage: "magnifyingglass")
                        .padding()
                }
                .cornerRadius(8)
                .touchBarItemPresence(.optional("xbible.study.search"))
                
                Button(action: {
                    statusMessage = isSplitViewPresented ? "Close Study Tools (Touch Bar)" : "Open Study Tools (Touch Bar)"
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isSplitViewPresented.toggle()
                    }
                    DispatchQueue.main.async {
                        self.isStudyViewFocused = false
                        self.isStudyViewFocused = true
                    }
                }) {
                    Label(
                        isSplitViewPresented ? "Close Study Tools" : "Open Study Tools",
                        systemImage: "sidebar.right"
                    )
                    .padding()
                }
                .cornerRadius(8)
                .touchBarItemPresence(.default("xbible.study.toggleStudyTools"))            }
        }
            .buttonStyle(.bordered)
#endif
        
        HStack(spacing: 0) {
            studyReaderPane
#if os(macOS)
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
#endif
        }
#if os(macOS)
        .background(StudyViewFirstResponder(isFirstResponder: Binding(
            get: { self.isStudyViewFocused },
            set: { self.isStudyViewFocused = $0 }
        )))
        .focusable()
        .focusEffectDisabled()
        .focused($isStudyViewFocused)

        .touchBar {
            bibleStudyTouchBar
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search...")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                PopoverButton(
                    label: wrapper.selectedModule,
                    title: "Bible Versions",
                    isPresented: $showModulePicker
                ) {
                    modulePickerContent
                }
                
                PopoverButton(label: wrapper.selectedBook, title: "Select Book", isPresented: $showBookPicker) {
                    bookPickerContent
                }
                
                PopoverButton(label: "\(wrapper.selectedChapter)", title: "Chapter", isPresented: $showChapterPicker) {
                    chapterPickerContent
                }
            }
        }
#endif
        
        .onAppear {
            initializeData()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isStudyViewFocused = true
            }
        }
        .onTapGesture {
            self.isStudyViewFocused = true
        }
        
#if os(iOS)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PopoverButton(
                    label: "\(wrapper.selectedBook) \(wrapper.selectedChapter)",
                    title: "Select Passage",
                    isPresented: $showBookPicker
                ) {
                    VStack(spacing: 0) {
                        bookPickerContent
                        Divider().padding(.vertical, 8)
                        chapterPickerContent
                    }
                }
            }
            
            ToolbarSpacer(.flexible, placement: .topBarLeading)
            
            ToolbarItem(placement: .topBarLeading) {
                PopoverButton(
                    label: wrapper.selectedModule,
                    title: "Bible Versions",
                    isPresented: $showModulePicker
                ) {
                    modulePickerContent
                }
            }
        }
#endif
        
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
    private var studyReaderPane: some View {
        GeometryReader { geometry in
            let isMobile = geometry.size.width < 500
            
            ZStack {
                ScrollView {
                    HStack {
                        Spacer(minLength: 0)
                        VStack(alignment: .leading, spacing: isMobile ? 24 : 40) {
                            ForEach(0..<sections.count, id: \.self) { index in
                                sectionView(sections[index])
                            }
                        }
                        .padding(.horizontal, isMobile ? 16 : 40)
                        .padding(.vertical, isMobile ? 20 : 40)
                        .frame(maxWidth: isMobile ? .infinity : 1200)
                        Spacer(minLength: 0)
                    }
                    .padding()
                }
                
                HStack(alignment: .bottom) {
                    NavigationRectButton(icon: "chevron.left", action: goToPreviousChapter, isDisabled: !canGoToPrevious(), isSide: true)
                    Spacer()
                    NavigationRectButton(icon: "chevron.right", action: goToNextChapter, isDisabled: !canGoToNext(), isSide: true)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func sectionView(_ section: ModuleSection) -> some View {
        VStack(alignment: section.textDirection == .rtl ? .trailing : .leading, spacing: 20) {
            if !section.title.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(0..<section.title.count, id: \.self) { index in
                        wordView(for: section, at: index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            ForEach(section.verses, id: \.osisId) { verse in
                verseView(verse)
            }
        }
    }
    
    private func verseView(_ verse: XbibleEngine.Verse) -> some View {
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
            Text("Chapters")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                ForEach(1...total, id: \.self) { ch in
                    chapterCell(for: ch)
                }
            }
        }
        .padding()
        // Responsive size caps that respect both macOS windows and iPad displays elegantly
        .frame(minWidth: 280, maxWidth: 320)
        .frame(height: 350)
    }
    
    private var modulePickerContent: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 140))], spacing: 12) {
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
            .padding(.top, 4)
        }
        .padding()
        .frame(minWidth: 220, maxWidth: 280)
        .frame(height: 300)
    }
    
    private var bookPickerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Books")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))], spacing: 10) {
                    ForEach(availableBooks, id: \.name) { book in
                        selectionRow(book.name, isSelected: wrapper.selectedBook == book.name) {
                            wrapper.selectedBook = book.name
                            #if os(macOS)
                            showBookPicker = false
                            #endif
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding()
        // Expanded boundaries specifically tailored for regular iPad split frames or landscape options
        .frame(minWidth: 460, maxWidth: 520)
        .frame(height: 400)
    }
    
    func chapterCell(for ch: Int) -> some View {
        Button(action: {
            wrapper.selectedChapter = ch
            showChapterPicker = false
            showBookPicker = false // Closes combined sheet on iOS
        }) {
            Text("\(ch)")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(wrapper.selectedChapter == ch ? Color.accentColor : Color.primary.opacity(0.08))
                .foregroundColor(wrapper.selectedChapter == ch ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    func selectionRow(_ text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(isSelected ? Color.accentColor : Color.primary.opacity(0.05))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    func moduleSelectionRow(_ version: String, language: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 2) {
                Text(version)
                    .font(.system(size: 14, weight: .bold))
                Text(language.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.accentColor : Color.primary.opacity(0.05))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // --- ENGINE CONNECTIVITY LOGIC ---
    
    func initializeData() {
        guard let engine = wrapper.engine else { return }
        
        wrapper.engineQueue.async {
            let modules = engine.getBibleModules()
            let lexicons = engine.getLexiconModules()
            let commentaries = engine.getCommentaryModules()
            
            DispatchQueue.main.async {
                self.availableModules = modules
                
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
            DispatchQueue.main.async {
                self.sections = results
                self.loadCommentaryContent()
            }
        }
    }
    
    func lookupWord(_ word: XbibleEngine.Word) {
        let cleanWord = word.text.trimmingCharacters(in: .punctuationCharacters)
        guard !cleanWord.isEmpty else { return }
        
        selectedWordForLookup = cleanWord
        selectedTab = .dictionary
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isSplitViewPresented = true
        }
        isDictionaryLoading = true
        
        let query = DictionaryQuery(word: cleanWord, strongs: [], language: word.language)
        
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
        guard !selectedStrongsForLookup.isEmpty else {
            self.lexiconResults = []
            return
        }

        isLexiconLoading = true
        let reference = selectedStrongsForLookup
        let currentModule = selectedLexiconModule
        let targetLanguage = availableLexicons.first(where: { $0.name == currentModule })?.language ?? "en"

        wrapper.engineQueue.async {
            guard let engine = wrapper.engine else { return }
            let query = LexiconQuery(strongsNumber: reference, language: targetLanguage)
            let response = engine.lookupStrongsNumber(query: query)

            DispatchQueue.main.async {
                self.lexiconResults = response.results
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
    let title: String
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: { isPresented.toggle() }) {
            HStack(spacing: 4) {
                Text(label)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.5)
            }
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
            
#if os(macOS)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
#else
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .cornerRadius(16)
#endif
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
#if os(iOS)
            // Modern sheet presentation structure on iPhone / iPad fallbacks
            NavigationStack {
                content()
                    .padding()
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: { isPresented = false }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
            }
            .presentationCompactAdaptation(.sheet)
            .presentationDragIndicator(.visible)
            .presentationDetents([.medium, .large])
#else
            content()
#endif
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
