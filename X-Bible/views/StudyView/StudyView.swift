//
//  StudyView.swift
//  XBible
//
//  Created by Zoe Brooklyn on 4/21/26.
//

import SwiftUI
import XbibleEngine
import SwiftData
import Foundation
import Combine

#if os(macOS)
import AppKit
#endif


// MARK: - Main View
struct StudyView: View {
    @EnvironmentObject var wrapper: SwordEngineWrapper
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
        
    @StateObject private var viewModel = StudyViewModel()
    
    // Custom Sidebar Overlay Toggles
    @State private var showModulePicker = false
    @State private var showBookPicker = false
    @State private var showChapterPicker = false
    @State private var activePickerTab: Int = 0 // 0 = Books, 1 = Chapters
    @State private var statusMessage = "Ready"
    
    // iOS Tabs Gallery Sheet Presenter
    @State private var isShowingTabsGallery = false
    
    // Toolbar Menus
    @State private var showTweaksPopover = false
    @State private var showMorePopover = false
    
    //text config
    @Query private var textConfigs: [TextConfig]
    
    @Namespace private var tabNamespace
    
    // MARK: - Helpers
    
    private var activeTabBinding: Binding<TabInstance>? {
        guard let index = viewModel.activeTabIndex else { return nil }
        return Binding(
            get: { viewModel.tabs[index] },
            set: { viewModel.tabs[index] = $0 }
        )
    }
    
    private var osIsMac: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
    
    private var useSidebarOverlay: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad || verticalSizeClass == .compact
        #else
        return false
        #endif
    }
    
    // Safe defaults that bridge the optional wrapper values
    private var safeDefaultModule: String {
        if let module = wrapper.selectedModule, !module.isEmpty {
            return module
        }
        return viewModel.availableModules.first?.name ?? ""
    }
    
    private var safeDefaultBook: String {
        if let book = wrapper.selectedBook, !book.isEmpty {
            return book
        }
        return viewModel.availableBooks.first?.name ?? ""
    }
    
    private var safeDefaultChapter: Int {
        wrapper.selectedChapter ?? 1
    }
    
    private var currentConfig: TextConfig {
        if let existing = textConfigs.first {
            return existing
        } else {
            let newConfig = TextConfig()
            modelContext.insert(newConfig)
            try? modelContext.save()
            return newConfig
        }
    }
    
    init() { }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if let activeBinding = activeTabBinding {
                ZStack {
                    HStack(spacing: 0) {
                        studyReaderPane(for: activeBinding)
                        
#if os(macOS)
                        if activeBinding.wrappedValue.isSplitViewPresented {
                            SplitDivider(detailWidth: activeBinding.detailWidth)
                            
                            SplitDetailPane(
                                isPresented: activeBinding.isSplitViewPresented,
                                selectedTab: activeBinding.selectedTab,
                                width: activeBinding.wrappedValue.detailWidth,
                                selectedWordForLookup: activeBinding.selectedWordForLookup,
                                dictionaryResults: activeBinding.dictionaryResults,
                                isDictionaryLoading: activeBinding.wrappedValue.isDictionaryLoading,
                                onWordClick: { word in lookupWord(word) },
                                selectedStrongsForLookup: activeBinding.selectedStrongsForLookup,
                                selectedLexiconModule: activeBinding.selectedLexiconModule,
                                availableLexicons: viewModel.availableLexicons,
                                lexiconResults: activeBinding.wrappedValue.lexiconResults,
                                isLexiconLoading: activeBinding.wrappedValue.isLexiconLoading,
                                onLexiconModuleChanged: { loadLexiconContent() },
                                selectedCommentaryModule: activeBinding.selectedCommentaryModule,
                                availableCommentaries: viewModel.availableCommentaries,
                                commentaryResults: activeBinding.wrappedValue.commentaryResults,
                                isCommentaryLoading: activeBinding.wrappedValue.isCommentaryLoading,
                                onCommentaryModuleChanged: {},
                                currentCommentaryReference: activeBinding.wrappedValue.currentCommentaryReference
                            )
                            .transition(.move(edge: .trailing))
                        }
#endif
                    }
                    
                    // iOS Custom Drawer Overlays
#if os(iOS)
                    if useSidebarOverlay && (showBookPicker || showModulePicker) {
                        Color.black.opacity(0.25)
                            .edgesIgnoringSafeArea(.all)
                            .transition(.opacity)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showBookPicker = false
                                    showModulePicker = false
                                }
                            }
                        
                        HStack(spacing: 0) {
                            Spacer()
                            VStack(spacing: 0) {
                                if showBookPicker {
                                    VStack(spacing: 16) {
                                        Picker("Selection Mode", selection: $activePickerTab) {
                                            Text("Books").tag(0)
                                            Text("Chapters").tag(1)
                                        }
                                        .pickerStyle(.segmented)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 12)
                                        
                                        if activePickerTab == 0 {
                                            bookPickerContent(for: activeBinding)
                                        } else {
                                            chapterPickerContent(for: activeBinding)
                                        }
                                    }
                                } else if showModulePicker {
                                    modulePickerContent(for: activeBinding)
                                        .padding(.top, 12)
                                }
                                Spacer()
                            }
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            showBookPicker = false
                                            showModulePicker = false
                                        }
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 16, weight: .semibold))
                                            .padding(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(width: 320)
                            .background(Color(uiColor: .systemBackground))
                            .shadow(color: Color.black.opacity(0.15), radius: 10, x: -5, y: 0)
                            .transition(.move(edge: .trailing))
                        }
                        .edgesIgnoringSafeArea(.bottom)
                    }
#endif
                }
                .onChange(of: activeBinding.wrappedValue.selectedModule) { _, _ in
                    updateBooks()
                }
                .onChange(of: activeBinding.wrappedValue.selectedBook) { _, _ in
                    if let index = viewModel.activeTabIndex {
                        viewModel.tabs[index].selectedChapter = 1
                    }
                    loadContent()
                }
                .onChange(of: activeBinding.wrappedValue.selectedChapter) { _, _ in
                    loadContent()
                }
            } else {
                ContentUnavailableView(
                    "No Open Tabs",
                    systemImage: "book.pages",
                    description: Text("Open a study session tab to view scriptures.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
#if os(macOS)
        .toolbar {
            if let activeBinding = activeTabBinding {
                
                ToolbarItemGroup(placement: .secondaryAction) {
                    PopoverButton(
                        label: activeBinding.wrappedValue.selectedModule.isEmpty
                            ? "Select Module"
                            : activeBinding.wrappedValue.selectedModule,
                        title: "Bible Versions",
                        isPresented: $showModulePicker,
                        bypassPopover: false
                    ) {
                        modulePickerContent(for: activeBinding)
                    }
                    
                    PopoverButton(
                        label: activeBinding.wrappedValue.selectedBook.isEmpty
                            ? "Select Book"
                            : activeBinding.wrappedValue.selectedBook,
                        title: "Select Book",
                        isPresented: $showBookPicker,
                        bypassPopover: false
                    ) {
                        bookPickerContent(for: activeBinding)
                    }
                    
                    PopoverButton(
                        label: "\(activeBinding.wrappedValue.selectedChapter)",
                        title: "Chapter",
                        isPresented: $showChapterPicker,
                        bypassPopover: false
                    ) {
                        chapterPickerContent(for: activeBinding)
                    }
                }
                
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showTweaksPopover.toggle()
                    } label: {
                        Image(systemName: "textformat")
                    }
                    .help("Tweaks & Settings")
                    .popover(isPresented: $showTweaksPopover, arrowEdge: .bottom) {
                        FontSettingsContent()
                    }
                    
                    Button {
                        showMorePopover.toggle()
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .help("More")
                    .popover(isPresented: $showMorePopover, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 8) {
                            Button("Duplicate Current Tab") {
                                showMorePopover = false
                                duplicateCurrentTab()
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                            
                            Button("Export Passage...") {
                                showMorePopover = false
                                // TODO: Add export action
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .frame(width: 180)
                    }
                }
                
                ToolbarSpacer(.fixed)
                
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        // search action
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .help("Search")
                }
                
                ToolbarItem(placement: .accessoryBar(id: "tab-items")) {
                    macOSWindowTabsView()
                }
                
                ToolbarItem(placement: .accessoryBar(id: "tab-items")) {
                    Button(action: createNewTab) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 22, height: 22)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Open New Tab")
                }
            }
        }
#endif
        .onAppear {
            initializeData()
        }
#if os(iOS)
        .toolbar {
            if let activeBinding = activeTabBinding {
                ToolbarItem(placement: .topBarLeading) {
                    PopoverButton(
                        label: activeBinding.wrappedValue.selectedBook.isEmpty
                            ? "Select Passage"
                            : "\(activeBinding.wrappedValue.selectedBook) \(activeBinding.wrappedValue.selectedChapter)",
                        title: "Select Passage",
                        isPresented: $showBookPicker,
                        bypassPopover: useSidebarOverlay
                    ) {
                        VStack(spacing: 16) {
                            Picker("Selection Mode", selection: $activePickerTab) {
                                Text("Books").tag(0)
                                Text("Chapters").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            
                            if activePickerTab == 0 {
                                bookPickerContent(for: activeBinding)
                            } else {
                                chapterPickerContent(for: activeBinding)
                            }
                        }
                    }
                }
                
                ToolbarSpacer(.flexible, placement: .topBarLeading)
                
                ToolbarItem(placement: .topBarLeading) {
                    PopoverButton(
                        label: activeBinding.wrappedValue.selectedModule.isEmpty
                            ? "Select Module"
                            : activeBinding.wrappedValue.selectedModule,
                        title: "Bible Versions",
                        isPresented: $showModulePicker,
                        bypassPopover: useSidebarOverlay
                    ) {
                        modulePickerContent(for: activeBinding)
                    }
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: { isShowingTabsGallery = true }) {
                        Image(systemName: "square.on.square")
                    }
                    .badge(viewModel.tabs.count)
                }
            }
        }
        .sheet(isPresented: $isShowingTabsGallery) {
            TabsGalleryView(
                tabs: $viewModel.tabs,
                selectedTabId: $viewModel.selectedTabId,
                createNewTabAction: createNewTab,
                closeTabAction: closeTab,
                onSelect: { loadContent() }
            )
        }
#endif
        .backgroundStyle(.clear)
        .onChange(of: wrapper.engineVersion) { _, _ in initializeData() }
        .onReceive(NotificationCenter.default.publisher(for: .requestTabDuplication)) { _ in
            self.duplicateCurrentTab()
        }
    }

    // MARK: - Tab Actions
    
    private func createNewTab() {
        let module = safeDefaultModule
        let book = safeDefaultBook
        let chapter = safeDefaultChapter
        
        let newTab = TabInstance(
            selectedModule: module,
            selectedBook: book,
            selectedChapter: chapter
        )
        
        viewModel.tabs.append(newTab)
        viewModel.selectedTabId = newTab.id
        
        if !module.isEmpty {
            updateBooks()
        }
    }
    
    private func duplicateCurrentTab() {
        guard let index = viewModel.activeTabIndex else {
            createNewTab()
            return
        }
        
        let source = viewModel.tabs[index]
        let duplicated = TabInstance(
            selectedModule: source.selectedModule,
            selectedBook: source.selectedBook,
            selectedChapter: source.selectedChapter
        )
        
        viewModel.tabs.append(duplicated)
        viewModel.selectedTabId = duplicated.id
        loadContent()
    }
    
    private func closeTab(id: UUID) {
        guard let index = viewModel.tabs.firstIndex(where: { $0.id == id }) else { return }
        viewModel.tabs.remove(at: index)
        
        if viewModel.selectedTabId == id {
            viewModel.selectedTabId = viewModel.tabs.last?.id
            loadContent()
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func macOSWindowTabsView() -> some View {
        if !viewModel.tabs.isEmpty {
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(viewModel.tabs.enumerated()), id: \.element.id) { index, tab in
                            macOSIndividualTabItem(for: tab)
                            
                            if index < viewModel.tabs.count - 1 {
                                Divider()
                                    .frame(height: 20)
                                    .foregroundColor(.secondary.opacity(0.3))
                            }
                        }
                    }
                    .frame(minWidth: geo.size.width)
                    .padding(.horizontal, 2)
                }
            }
            .frame(height: 26)
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
            .background(Capsule().fill(.regularMaterial))
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func macOSIndividualTabItem(for tab: TabInstance) -> some View {
        let isSelected = viewModel.selectedTabId == tab.id
        
        HStack(spacing: 6) {
            Image(systemName: tab.selectedBook.isEmpty ? "doc.plaintext" : "book.closed.fill")
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .accentColor : .secondary)
            
            Text(tab.selectedBook.isEmpty
                 ? "Empty Tab"
                 : "\(tab.selectedBook) \(tab.selectedChapter)")
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .primary : .primary.opacity(0.8))
                .lineLimit(1)
            
            if !tab.selectedModule.isEmpty {
                Text(tab.selectedModule)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(3)
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 4)
            
            Button(action: { closeTab(id: tab.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .black))
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 14)
                    .background(Color.primary.opacity(isSelected ? 0.1 : 0.0))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(height: 26)
        .frame(minWidth: 120)
        .frame(maxWidth: .infinity)
        .background {
            if isSelected {
                Capsule()
                    .glassEffect(.regular, in: .capsule)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedTabId = tab.id
            loadContent()
        }
    }
    
    @ViewBuilder
    private func studyReaderPane(for tab: Binding<TabInstance>) -> some View {
        GeometryReader { geometry in
            let isMobile = geometry.size.width < 500
            
            ZStack {
                ScrollView {
                    HStack {
                        Spacer(minLength: 0)
                        VStack(alignment: .leading, spacing: isMobile ? 24 : 40) {
                            ForEach(0..<tab.wrappedValue.sections.count, id: \.self) { index in
                                sectionView(tab.wrappedValue.sections[index])
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
                    NavigationRectButton(
                        icon: "chevron.left",
                        action: goToPreviousChapter,
                        isDisabled: !canGoToPrevious(),
                        isSide: true
                    )
                    Spacer()
                    NavigationRectButton(
                        icon: "chevron.right",
                        action: goToNextChapter,
                        isDisabled: !canGoToNext(),
                        isSide: true
                    )
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func sectionView(_ section: ModuleSection) -> some View {
        let alignment: HorizontalAlignment = section.textDirection == .rtl ? .trailing : .leading
        
        VStack(alignment: alignment, spacing: 20) {
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
            onWordTextClicked: { word in lookupWord(word) },
            onStrongsClicked: { strongs in lookupStrongs(strongs) }
        )
    }
    
    private func wordView(for section: ModuleSection, at index: Int) -> some View {
        let currentWord = section.title[index]
        return WordView(word: currentWord, onWordTextClicked: { self.lookupWord(currentWord) })
    }
    
    // MARK: - Pickers
    
    @ViewBuilder
    private func chapterPickerContent(for tab: Binding<TabInstance>) -> some View {
        let chapters = viewModel.availableBooks.first(where: { $0.name == tab.wrappedValue.selectedBook })?.chapters ?? []
        let total = max(1, chapters.count)
        let columnsCount = useSidebarOverlay ? 4 : (horizontalSizeClass == .compact && !osIsMac ? 8 : 5)
        
        VStack(alignment: .leading, spacing: 12) {
            if osIsMac {
                Text("Chapters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columnsCount), spacing: 10) {
                    ForEach(1...total, id: \.self) { ch in
                        chapterCell(for: ch, tab: tab)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
            }
        }
        #if os(macOS)
        .padding(24)
        .frame(minWidth: 280, maxWidth: 320)
        .frame(height: 350)
        #else
        .frame(maxWidth: .infinity)
        #endif
    }
    
    @ViewBuilder
    private func modulePickerContent(for tab: Binding<TabInstance>) -> some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110, maximum: 140))], spacing: 12) {
                    ForEach(viewModel.availableModules, id: \.name) { module in
                        moduleSelectionRow(
                            module.name,
                            language: module.language,
                            isSelected: tab.wrappedValue.selectedModule == module.name
                        ) {
                            if let index = viewModel.activeTabIndex {
                                viewModel.tabs[index].selectedModule = module.name
                            }
                            withAnimation { showModulePicker = false }
                            updateBooks()
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.horizontal, 16)
            }
        }
        #if os(macOS)
        .padding()
        .frame(minWidth: 220, maxWidth: 280)
        .frame(height: 300)
        #else
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        #endif
    }
    
    @ViewBuilder
    private func bookPickerContent(for tab: Binding<TabInstance>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if osIsMac {
                Text("Books")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 10) {
                    ForEach(viewModel.availableBooks, id: \.name) { book in
                        selectionRow(book.name, isSelected: tab.wrappedValue.selectedBook == book.name) {
                            if let index = viewModel.activeTabIndex {
                                viewModel.tabs[index].selectedBook = book.name
                                viewModel.tabs[index].selectedChapter = 1
                            }
                            #if os(macOS)
                            showBookPicker = false
                            #else
                            withAnimation(.easeInOut(duration: 0.2)) { activePickerTab = 1 }
                            #endif
                            loadContent()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
            }
        }
        #if os(macOS)
        .padding()
        .frame(minWidth: 460, maxWidth: 520)
        .frame(height: 400)
        #else
        .frame(maxWidth: .infinity)
        #endif
    }
    
    private func chapterCell(for ch: Int, tab: Binding<TabInstance>) -> some View {
        Button(action: {
            if let index = viewModel.activeTabIndex {
                viewModel.tabs[index].selectedChapter = ch
            }
            withAnimation {
                showChapterPicker = false
                showBookPicker = false
            }
            #if os(iOS)
            activePickerTab = 0
            #endif
            loadContent()
        }) {
            Text("\(ch)")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(tab.wrappedValue.selectedChapter == ch ? Color.accentColor : Color.primary.opacity(0.08))
                .foregroundColor(tab.wrappedValue.selectedChapter == ch ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private func selectionRow(_ text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(isSelected ? Color.accentColor : Color.primary.opacity(0.05))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private func moduleSelectionRow(_ version: String, language: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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
    
    // MARK: - Engine Integration
    
    private func initializeData() {
        guard let engine = wrapper.engine else { return }
        
        wrapper.engineQueue.async {
            let modules = engine.getBibleModules()
            let lexicons = engine.getLexiconModules()
            let commentaries = engine.getCommentaryModules()
            
            DispatchQueue.main.async {
                self.viewModel.availableModules = modules
                self.viewModel.availableLexicons = lexicons
                self.viewModel.availableCommentaries = commentaries
                
                if self.viewModel.tabs.isEmpty {
                    self.createNewTab()
                } else {
                    self.updateBooks()
                }
            }
        }
    }
    
    private func updateBooks() {
        guard let engine = wrapper.engine,
              let tabId = viewModel.selectedTabId,
              let index = viewModel.tabs.firstIndex(where: { $0.id == tabId }) else { return }
        
        var currentModule = viewModel.tabs[index].selectedModule
        if currentModule.isEmpty {
            currentModule = viewModel.availableModules.first?.name ?? ""
        }
        
        guard !currentModule.isEmpty else {
            viewModel.availableBooks = []
            return
        }
        
        let capturedTabId = tabId
        
        wrapper.engineQueue.async {
            let books = engine.getBooks(moduleName: currentModule)
            
            DispatchQueue.main.async {
                self.viewModel.availableBooks = books
                
                guard let idx = self.viewModel.tabs.firstIndex(where: { $0.id == capturedTabId }) else { return }
                
                if self.viewModel.tabs[idx].selectedModule.isEmpty {
                    self.viewModel.tabs[idx].selectedModule = currentModule
                }
                
                if !books.contains(where: { $0.name == self.viewModel.tabs[idx].selectedBook }) {
                    self.viewModel.tabs[idx].selectedBook = books.first?.name ?? ""
                    self.viewModel.tabs[idx].selectedChapter = 1
                }
                
                self.loadContent()
            }
        }
    }
    
    private func loadContent() {
        guard let engine = wrapper.engine,
              let tabId = viewModel.selectedTabId,
              let index = viewModel.tabs.firstIndex(where: { $0.id == tabId }) else { return }
        
        let tab = viewModel.tabs[index]
        
        guard !tab.selectedBook.isEmpty else {
            if let idx = viewModel.tabs.firstIndex(where: { $0.id == tabId }) {
                viewModel.tabs[idx].sections = []
            }
            return
        }
        
        var currentModule = tab.selectedModule
        if currentModule.isEmpty {
            currentModule = viewModel.availableModules.first?.name ?? ""
        }
        
        guard !currentModule.isEmpty else { return }
        
        let ref = "\(tab.selectedBook) \(tab.selectedChapter)"
        let capturedTabId = tabId
        
        wrapper.engineQueue.async {
            let results = engine.getChapterContent(moduleName: currentModule, reference: ref)
            
            DispatchQueue.main.async {
                guard let idx = self.viewModel.tabs.firstIndex(where: { $0.id == capturedTabId }) else { return }
                var updatedTab = self.viewModel.tabs[idx]
                updatedTab.sections = results
                self.viewModel.tabs[idx] = updatedTab
                
                self.loadCommentaryContent()
            }
        }
    }
    
    // MARK: - Lookups
    
    private func lookupWord(_ word: XbibleEngine.Word) {
        let cleanWord = word.text.trimmingCharacters(in: .punctuationCharacters)
        guard !cleanWord.isEmpty, let index = viewModel.activeTabIndex else { return }
        
        viewModel.tabs[index].selectedWordForLookup = cleanWord
        viewModel.tabs[index].selectedTab = .dictionary
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            viewModel.tabs[index].isSplitViewPresented = true
        }
        viewModel.tabs[index].isDictionaryLoading = true
        
        let query = DictionaryQuery(word: cleanWord, strongs: [], language: word.language)
        let capturedTabId = viewModel.tabs[index].id
        
        wrapper.engineQueue.async {
            guard let engine = self.wrapper.engine else { return }
            let response = engine.lookupDictionary(query: query)
            
            DispatchQueue.main.async {
                guard let idx = self.viewModel.tabs.firstIndex(where: { $0.id == capturedTabId }) else { return }
                var updatedTab = self.viewModel.tabs[idx]
                updatedTab.dictionaryResults = response.results
                updatedTab.isDictionaryLoading = false
                self.viewModel.tabs[idx] = updatedTab
            }
        }
    }
    
    private func lookupStrongs(_ strongsCode: String) {
        guard !strongsCode.isEmpty, let index = viewModel.activeTabIndex else { return }
        
        viewModel.tabs[index].selectedStrongsForLookup = strongsCode
        viewModel.tabs[index].selectedTab = .lexicon
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            viewModel.tabs[index].isSplitViewPresented = true
        }
        
        if viewModel.availableLexicons.isEmpty {
            loadLexiconsMetadata { self.loadLexiconContent() }
        } else {
            loadLexiconContent()
        }
    }
    
    private func loadLexiconsMetadata(completion: (() -> Void)? = nil) {
        wrapper.engineQueue.async {
            guard let engine = self.wrapper.engine else { return }
            let lexicons = engine.getLexiconModules()
            
            DispatchQueue.main.async {
                self.viewModel.availableLexicons = lexicons
                
                if let index = self.viewModel.activeTabIndex {
                    let current = self.viewModel.tabs[index].selectedLexiconModule
                    if current.isEmpty || !lexicons.contains(where: { $0.name == current }) {
                        self.viewModel.tabs[index].selectedLexiconModule = lexicons.first?.name ?? ""
                    }
                }
                completion?()
            }
        }
    }
    
    private func loadLexiconContent() {
        guard let index = viewModel.activeTabIndex else { return }
        let tab = viewModel.tabs[index]
        
        guard !tab.selectedStrongsForLookup.isEmpty else {
            viewModel.tabs[index].lexiconResults = []
            return
        }
        
        viewModel.tabs[index].isLexiconLoading = true
        
        let reference = tab.selectedStrongsForLookup
        let currentModule = tab.selectedLexiconModule
        let targetLanguage = viewModel.availableLexicons.first(where: { $0.name == currentModule })?.language ?? "en"
        let capturedTabId = tab.id
        
        wrapper.engineQueue.async {
            guard let engine = self.wrapper.engine else { return }
            let query = LexiconQuery(strongsNumber: reference, language: targetLanguage)
            let response = engine.lookupStrongsNumber(query: query)
            
            DispatchQueue.main.async {
                guard let idx = self.viewModel.tabs.firstIndex(where: { $0.id == capturedTabId }) else { return }
                var updatedTab = self.viewModel.tabs[idx]
                updatedTab.lexiconResults = response.results
                updatedTab.isLexiconLoading = false
                self.viewModel.tabs[idx] = updatedTab
            }
        }
    }
    
    private func loadCommentaryContent() {
        guard let index = viewModel.activeTabIndex else { return }
        let tab = viewModel.tabs[index]
        
        guard !tab.selectedCommentaryModule.isEmpty else {
            viewModel.tabs[index].commentaryResults = []
            return
        }
        
        viewModel.tabs[index].isCommentaryLoading = true
        
        let moduleName = tab.selectedCommentaryModule
        let reference = "\(tab.selectedBook) \(tab.selectedChapter)"
        viewModel.tabs[index].currentCommentaryReference = reference
        let capturedTabId = tab.id
        
        wrapper.engineQueue.async {
            guard let engine = self.wrapper.engine else { return }
            let results = engine.getChapterContent(moduleName: moduleName, reference: reference)
            
            DispatchQueue.main.async {
                guard let idx = self.viewModel.tabs.firstIndex(where: { $0.id == capturedTabId }) else { return }
                var updatedTab = self.viewModel.tabs[idx]
                updatedTab.commentaryResults = results
                updatedTab.isCommentaryLoading = false
                self.viewModel.tabs[idx] = updatedTab
            }
        }
    }
    
    // MARK: - Chapter Navigation
    
    private func canGoToPrevious() -> Bool {
        guard let index = viewModel.activeTabIndex,
              let bookIndex = viewModel.availableBooks.firstIndex(where: { $0.name == viewModel.tabs[index].selectedBook }) else {
            return false
        }
        return viewModel.tabs[index].selectedChapter > 1 || bookIndex > 0
    }
    
    private func canGoToNext() -> Bool {
        guard let index = viewModel.activeTabIndex,
              let bookIndex = viewModel.availableBooks.firstIndex(where: { $0.name == viewModel.tabs[index].selectedBook }) else {
            return false
        }
        let chapters = viewModel.availableBooks[bookIndex].chapters
        return viewModel.tabs[index].selectedChapter < chapters.count || bookIndex < viewModel.availableBooks.count - 1
    }
    
    private func goToPreviousChapter() {
        guard let index = viewModel.activeTabIndex,
              let bookIndex = viewModel.availableBooks.firstIndex(where: { $0.name == viewModel.tabs[index].selectedBook }) else {
            return
        }
        
        if viewModel.tabs[index].selectedChapter > 1 {
            viewModel.tabs[index].selectedChapter -= 1
        } else if bookIndex > 0 {
            let previousBook = viewModel.availableBooks[bookIndex - 1]
            viewModel.tabs[index].selectedBook = previousBook.name
            viewModel.tabs[index].selectedChapter = previousBook.chapters.count
        }
        loadContent()
    }
    
    private func goToNextChapter() {
        guard let index = viewModel.activeTabIndex,
              let bookIndex = viewModel.availableBooks.firstIndex(where: { $0.name == viewModel.tabs[index].selectedBook }) else {
            return
        }
        
        let chapters = viewModel.availableBooks[bookIndex].chapters
        
        if viewModel.tabs[index].selectedChapter < chapters.count {
            viewModel.tabs[index].selectedChapter += 1
        } else if bookIndex < viewModel.availableBooks.count - 1 {
            let nextBook = viewModel.availableBooks[bookIndex + 1]
            viewModel.tabs[index].selectedBook = nextBook.name
            viewModel.tabs[index].selectedChapter = 1
        }
        loadContent()
    }
}

