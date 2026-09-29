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

// MARK: - Engine SearchType — presentation helpers
//
// The canonical `SearchType` lives in XbibleEngine. We only extend it
// with display metadata for the toolbar / picker.

extension SearchType {
    var displayName: String {
        switch self {
        case .regularExpression: return "Regex"
        case .phrase:            return "Phrase"
        case .multiWord:         return "Multi Word"
        @unknown default:        return "Search"
        }
    }

    var iconName: String {
        switch self {
        case .regularExpression: return "asterisk"
        case .phrase:            return "text.quote"
        case .multiWord:         return "text.word.spacing"
        @unknown default:        return "magnifyingglass"
        }
    }

    static var allCasesOrdered: [SearchType] {
        [.multiWord, .phrase, .regularExpression]
    }
}

// MARK: - Main View
struct StudyView: View {
    @EnvironmentObject var wrapper: SwordEngineWrapper
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @EnvironmentObject var viewModel: StudyViewModel

    // MARK: - View-only UI state

    // iOS custom sidebar overlays
    @State private var showModulePicker = false
    @State private var showBookPicker = false
    @State private var showChapterPicker = false
    @State private var activePickerTab: Int = 0   // 0 = Books, 1 = Chapters

    // Search-tab pickers
    @State private var showSearchModulePicker = false
    @State private var showSearchTypePicker = false

    // Toolbar menus
    @State private var showTweaksPopover = false
    @State private var showMorePopover = false

    

    // Text config
    @Query private var textConfigs: [TextConfig]

    @Namespace private var tabNamespace

    // MARK: - Derived / helpers

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

    private func binding(for tab: TabInstance) -> Binding<TabInstance> {
        guard let idx = viewModel.tabs.firstIndex(where: { $0.id == tab.id }) else {
            return .constant(tab)
        }
        return Binding(
            get: { viewModel.tabs[idx] },
            set: { viewModel.tabs[idx] = $0 }
        )
    }

    private var currentConfig: TextConfig {
        if let existing = textConfigs.first { return existing }
        let newConfig = TextConfig()
        modelContext.insert(newConfig)
        try? modelContext.save()
        return newConfig
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
                                onWordClick: { word in viewModel.lookupWord(word) },
                                selectedStrongsForLookup: activeBinding.selectedStrongsForLookup,
                                selectedLexiconModule: activeBinding.selectedLexiconModule,
                                availableLexicons: viewModel.availableLexicons,
                                lexiconResults: activeBinding.wrappedValue.lexiconResults,
                                isLexiconLoading: activeBinding.wrappedValue.isLexiconLoading,
                                onLexiconModuleChanged: { viewModel.loadLexiconContent() },
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
                    if useSidebarOverlay && (showBookPicker || showModulePicker || showSearchModulePicker || showSearchTypePicker) {
                        Color.black.opacity(0.25)
                            .edgesIgnoringSafeArea(.all)
                            .transition(.opacity)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    closeAllOverlays()
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
                                } else if showSearchModulePicker {
                                    searchModulePickerContent(for: activeBinding)
                                        .padding(.top, 12)
                                } else if showSearchTypePicker {
                                    searchTypePickerContent(for: activeBinding)
                                        .padding(.top, 12)
                                }
                                Spacer()
                            }
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            closeAllOverlays()
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
        .toolbar { macOSToolbar }
#endif
#if os(iOS)
        .toolbar { iOSPrimaryToolbar }
        .sheet(isPresented: $viewModel.showTabOverview) {
                TabsGalleryView(
                    onSelect: { viewModel.loadContentForActiveTab() }
                )
                .environmentObject(viewModel)
            }
#endif
        .onAppear {
            viewModel.configure(wrapper: wrapper, modelContext: modelContext)
            viewModel.initializeData()
        }
        .onChange(of: wrapper.engineVersion) { _, _ in
            viewModel.configure(wrapper: wrapper, modelContext: modelContext)
            viewModel.initializeData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestTabDuplication)) { _ in
            viewModel.duplicateCurrentTab()
        }
    }

    private func closeAllOverlays() {
        showBookPicker = false
        showModulePicker = false
        showChapterPicker = false
        showSearchModulePicker = false
        showSearchTypePicker = false
    }

    // MARK: - macOS Toolbar

#if os(macOS)
    @ToolbarContentBuilder
    private var macOSToolbar: some ToolbarContent {
        if let activeBinding = activeTabBinding {
            ToolbarItemGroup(placement: .secondaryAction) {
                switch activeBinding.wrappedValue.type {
                    
                case .bible:
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
                    
                case  .commentary:
                    PopoverButton(
                        label: activeBinding.wrappedValue.selectedCommentaryModule.isEmpty
                        ? "Select Module"
                        : activeBinding.wrappedValue.selectedCommentaryModule,
                        title: "Commentaries",
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
                    
                case .search:
                    EmptyView()
                case .generalBook:
                    EmptyView()
                case .dictionary:
                    EmptyView()
                case .lexicon:
                    EmptyView()
                case .parallel:
                    EmptyView()
                }
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.createNewTab(ofType: .search)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help("Search")
            }
            
            ToolbarSpacer(.fixed)
            
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showTweaksPopover.toggle()
                } label: {
                    Image(systemName: "textformat")
                }
                .help("Font & Settings")
                .popover(isPresented: $showTweaksPopover, arrowEdge: .bottom) {
                    FontSettingsContent()
                        .frame(width: 340, height: 480)
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
                            viewModel.duplicateCurrentTab()
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                        
                        Button("Export Passage...") {
                            showMorePopover = false
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .frame(width: 180)
                }
            }
            
            ToolbarItemGroup(placement: .accessoryBar(id: "tab-items")) {
                macOSWindowTabsView()
                NewTabMenu()
                    .menuStyle(.borderlessButton)
            }

        }
    }
#endif

    // MARK: - iOS Primary Toolbar (tab-relative)

#if os(iOS)
    @ToolbarContentBuilder
    private var iOSPrimaryToolbar: some ToolbarContent {
        if let activeBinding = activeTabBinding {
            switch activeBinding.wrappedValue.type {

            // ── Bible / General Book — passage + module, plus trailing menu
            case .bible, .generalBook:
                if activeBinding.wrappedValue.type.usesReaderPane {
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
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { viewModel.createNewTab(ofType: .search) } label: {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                        Button {
                            showTweaksPopover = true
                        } label: {
                            Label("Font & Settings", systemImage: "textformat")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .adaptivePresentation(
                        isPresented: $showTweaksPopover,
                        title: "Font & Settings",
                        detents: [.large],
                        popoverEdge: .top
                    ) {
                        FontSettingsContent()
                    }
                }

            // ── Search — module + type, no trailing menu
            case .search:
                ToolbarItem(placement: .topBarLeading) {
                    PopoverButton(
                        label: activeBinding.wrappedValue.selectedModule.isEmpty
                        ? "Select Module"
                        : activeBinding.wrappedValue.selectedModule,
                        title: "Search Module",
                        isPresented: $showSearchModulePicker,
                        bypassPopover: useSidebarOverlay
                    ) {
                        searchModulePickerContent(for: activeBinding)
                    }
                }

                ToolbarSpacer(.flexible, placement: .topBarLeading)

                ToolbarItem(placement: .topBarLeading) {
                    PopoverButton(
                        label: viewModel.searchType.displayName,
                        title: "Search Type",
                        isPresented: $showSearchTypePicker,
                        bypassPopover: useSidebarOverlay
                    ) {
                        searchTypePickerContent(for: activeBinding)
                    }
                }

            // ── Dictionary / Lexicon / Commentary / Parallel — title only
            case .dictionary:
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: TabType.dictionary.icon)
                            .foregroundStyle(TabType.dictionary.tint)
                        Text(TabType.dictionary.displayName)
                            .font(.headline)
                    }
                }

            case .lexicon:
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: TabType.lexicon.icon)
                            .foregroundStyle(TabType.lexicon.tint)
                        Text(TabType.lexicon.displayName)
                            .font(.headline)
                    }
                }

            case .commentary:
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: TabType.commentary.icon)
                            .foregroundStyle(TabType.commentary.tint)
                        Text(TabType.commentary.displayName)
                            .font(.headline)
                    }
                }

            case .parallel:
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Image(systemName: TabType.parallel.icon)
                            .foregroundStyle(TabType.parallel.tint)
                        Text(TabType.parallel.displayName)
                            .font(.headline)
                    }
                }
            }
        }
    }
#endif
    // MARK: - macOS Custom Tabs

#if os(macOS)
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
                                    .frame(height: 12)
                                    .foregroundColor(.secondary.opacity(0.3))
                            }
                        }
                    }
                    .frame(minWidth: geo.size.width)
                    .padding(.horizontal, 2)
                }
            }
            .frame(height: 25)
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
            Image(systemName: tab.type.icon)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? tab.type.tint : .secondary)

            Text(tab.displayTitle)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .primary : .primary.opacity(0.8))
                .lineLimit(1)

            if tab.type.requiresModule, !tab.selectedModule.isEmpty {
                Text(tab.selectedModule)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(tab.type.tint.opacity(0.12))
                    .cornerRadius(3)
                    .foregroundColor(tab.type.tint)
            }

            Spacer(minLength: 4)

            Button(action: { viewModel.closeTab(id: tab.id) }) {
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
        .frame(height: 25)
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
            viewModel.selectTab(id: tab.id)
        }
        .contextMenu {
            Button("Duplicate Tab") { viewModel.duplicateTab(id: tab.id) }
            Button("Close Tab", role: .destructive) { viewModel.closeTab(id: tab.id) }
            Divider()
            Button("Close Other Tabs") { viewModel.closeOtherTabs(keeping: tab.id) }
            Button("Close All Tabs", role: .destructive) { viewModel.closeAllTabs() }
        }
    }
#endif

    // MARK: - Reader Pane

    @ViewBuilder
    private func studyReaderPane(for tab: Binding<TabInstance>) -> some View {
        GeometryReader { geometry in
            ZStack {
                switch tab.wrappedValue.type {
                case .bible, .generalBook:
                    bibleReaderPane(for: tab, geometry: geometry)

                case .parallel:
                    parallelReaderPane(for: tab, geometry: geometry)

                case .search:
                    searchPane(for: tab, geometry: geometry)

                case .dictionary:
                    dictionaryPane(for: tab, geometry: geometry)

                case .lexicon:
                    lexiconPane(for: tab, geometry: geometry)

                case .commentary:
                    commentaryPane(for: tab, geometry: geometry)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Bible Reader Pane

    @ViewBuilder
    private func bibleReaderPane(for tab: Binding<TabInstance>, geometry: GeometryProxy) -> some View {
        BibleTabView(tab: tab)
    }

    // MARK: - Parallel Reader Pane (stub)

    @ViewBuilder
    private func parallelReaderPane(for tab: Binding<TabInstance>, geometry: GeometryProxy) -> some View {
        ContentUnavailableView(
            "Parallel View",
            systemImage: TabType.parallel.icon,
            description: Text("Compare two translations side by side — coming soon.")
        )
    }

    // MARK: - Search Pane

    @ViewBuilder
    private func searchPane(for tab: Binding<TabInstance>, geometry: GeometryProxy) -> some View {
        SearchTabView(
            tab: tab,
            availableModules: viewModel.availableModules,
            searchType: viewModel.searchType,
            onSearch: { query in
                viewModel.updateSearchQuery(query)
                viewModel.performSearch(query)
            },
            onModuleChange: { module in
                guard let idx = viewModel.activeTabIndex,
                      viewModel.tabs[idx].type == .search else { return }
                viewModel.tabs[idx].selectedModule = module
                viewModel.tabs[idx].searchResults = []
                viewModel.tabs[idx].searchHitsContent = [:]
                if !viewModel.tabs[idx].searchQuery.isEmpty {
                    viewModel.performSearch(viewModel.tabs[idx].searchQuery)
                }
            },
            onReferenceClick: { reference in
                openHitInNewBibleTab(reference: reference)
            },
            onCopyVerse: { reference, sections in
                let text = sections
                    .flatMap { $0.verses }
                    .flatMap { $0.words }
                    .map(\.text)
                    .joined(separator: " ")
                #if os(iOS)
                UIPasteboard.general.string = "\(reference): \(text)"
                #elseif os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(reference): \(text)", forType: .string)
                #endif
            },
            onOpenInNewTab: { hit in
                openHitInNewBibleTab(reference: hit.key)
            },
            onPreviewChapter: { reference in
                openHitInNewBibleTab(reference: reference)
            },
            onLexiconLookup: { reference in
                // Route to the lexicon of the first word if you want.
            }
        )
    }

    private func openHitInNewBibleTab(reference: String) {
        let parts = reference.split(separator: " ")
        guard parts.count >= 2, let chapter = Int(parts.last!) else { return }
        let book = parts.dropLast().joined(separator: " ")

        var newTab = TabInstance()
        newTab.type = .bible
        newTab.selectedModule = viewModel.activeTab?.selectedModule
            ?? viewModel.safeDefaultModule
        newTab.selectedBook = book
        newTab.selectedChapter = chapter

        viewModel.tabs.append(newTab)
        viewModel.selectedTabId = newTab.id
        viewModel.updateBooks()
    }
    
    @ViewBuilder
    private func searchHitRow(_ hit: SearchHit, tab: Binding<TabInstance>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(hit.key)
                .font(.headline)
                .foregroundStyle(tab.wrappedValue.type.tint)
            if let sections = tab.wrappedValue.searchHitsContent[hit.key] {
                let preview = sections
                    .flatMap { $0.verses }
                    .flatMap { $0.words }
                    .prefix(30)
                    .map(\.text)
                    .joined(separator: " ")
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Divider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Dictionary Pane

    @ViewBuilder
    private func dictionaryPane(for tab: Binding<TabInstance>, geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "character.book.closed")
                    .foregroundStyle(TabType.dictionary.tint)
                TextField("Look up a word…", text: Binding(
                    get: { tab.wrappedValue.selectedWordForLookup },
                    set: { newValue in
                        guard let idx = viewModel.activeTabIndex else { return }
                        viewModel.tabs[idx].selectedWordForLookup = newValue
                    }
                ))
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .onSubmit {
                    let q = tab.wrappedValue.selectedWordForLookup
                    if !q.isEmpty { viewModel.lookupWord(text: q) }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if tab.wrappedValue.isDictionaryLoading {
                ProgressView().padding()
            } else if tab.wrappedValue.dictionaryResults.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "Dictionary",
                    systemImage: TabType.dictionary.icon,
                    description: Text("Enter a word to look it up.")
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(tab.wrappedValue.dictionaryResults, id: \.key) { result in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(result.key).font(.headline)
                                Text(result.definition)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                Divider()
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - Lexicon / Commentary Panes (stubs)

    @ViewBuilder
    private func lexiconPane(for tab: Binding<TabInstance>, geometry: GeometryProxy) -> some View {
        ContentUnavailableView(
            "Lexicon",
            systemImage: TabType.lexicon.icon,
            description: Text("Look up a Strong's number to study its meaning.")
        )
    }

    @ViewBuilder
    private func commentaryPane(for tab: Binding<TabInstance>, geometry: GeometryProxy) -> some View {
        if (viewModel.availableCommentaries.isEmpty) {
            ContentUnavailableView(
                "Commentary",
                systemImage: TabType.commentary.icon,
                description: Text("Read commentary on a passage.")
            )
        } else{
            CommentaryTabView(tab: tab)
        }
    }


    // MARK: - Pickers

    @ViewBuilder
    private func chapterPickerContent(for tab: Binding<TabInstance>) -> some View {
        let chapters = viewModel.availableBooks
            .first(where: { $0.name == tab.wrappedValue.selectedBook })?
            .chapters ?? []
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
                    ForEach( viewModel.availableModules, id: \.name) { module in
                        moduleSelectionRow(
                            module.name,
                            language: module.language,
                            isSelected: tab.wrappedValue.selectedModule == module.name
                        ) {
                            switch tab.wrappedValue.type{
                            case .commentary:
                                viewModel.selectCommentaryModule(module.name);
                               // later to support other types
                            default:
                                viewModel.selectModule(module.name)
                            }
                           
                            withAnimation { showModulePicker = false }
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

    // MARK: - Search-specific pickers

    @ViewBuilder
    private func searchModulePickerContent(for tab: Binding<TabInstance>) -> some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110, maximum: 140))], spacing: 12) {
                    ForEach(viewModel.availableModules, id: \.name) { module in
                        moduleSelectionRow(
                            module.name,
                            language: module.language,
                            isSelected: tab.wrappedValue.selectedModule == module.name
                        ) {
                            guard let idx = viewModel.activeTabIndex,
                                  viewModel.tabs[idx].type == .search else { return }
                            viewModel.tabs[idx].selectedModule = module.name
                            viewModel.tabs[idx].searchResults = []
                            viewModel.tabs[idx].searchHitsContent = [:]
                            if !viewModel.tabs[idx].searchQuery.isEmpty {
                                viewModel.performSearch(viewModel.tabs[idx].searchQuery)
                            }
                            withAnimation { showSearchModulePicker = false }
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
    private func searchTypePickerContent(for tab: Binding<TabInstance>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(SearchType.allCasesOrdered, id: \.self) { type in
                Button {
                    viewModel.updateSearchType(type)
                    withAnimation { showSearchTypePicker = false }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: type.iconName)
                            .frame(width: 20)
                        Text(type.displayName)
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        if viewModel.searchType == type {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(viewModel.searchType == type
                                  ? Color.accentColor.opacity(0.12)
                                  : Color.primary.opacity(0.05))
                    )
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        #if os(macOS)
        .padding()
        .frame(minWidth: 220, maxWidth: 260)
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
                            viewModel.selectBook(book.name)
                            #if os(macOS)
                            showBookPicker = false
                            #else
                            withAnimation(.easeInOut(duration: 0.2)) { activePickerTab = 1 }
                            #endif
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
            viewModel.selectChapter(ch)
            withAnimation {
                showChapterPicker = false
                showBookPicker = false
            }
            #if os(iOS)
            activePickerTab = 0
            #endif
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
}
